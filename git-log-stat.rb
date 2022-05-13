#!/usr/bin/ruby

# Copyright 2022 hidenory
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'optparse'
require 'date'
require "./TaskManager"
require "./FileUtil"
require "./StrUtil"
require "./ExecUtil"
require "./GitUtil"


class HashUtil
	def self.toHashFromArray(srcArray)
		result = {}
		srcArray.each do |anItem|
			result[anItem.to_s] = anItem
		end
		return result
	end

	def self.toArrayFromHash(srHash)
		result = []
		srHash.each do |key, value|
			result.push( {:key=>key, :value=>value} )
		end
		return result
	end
end


class ResultCollector
	def initialize( mode, sort, outputFormat, enableGitPathOutput )
		@result = {}
		@_mutex = Mutex.new
		@mode = mode
		@sort = sort
		@outputFormat = outputFormat
		@enableGitPathOutput = enableGitPathOutput
	end

	def onResult( gitPath, duration, result )
		@_mutex.synchronize {
			_result = {}
			if @result.has_key?( gitPath ) then
				_result = @result[ gitPath ]
			end
			_result[ duration ] = result
			@result[ gitPath ] = _result
		}
	end

	def get2ndFieldName()
		return "author" if @mode == "author"
		return "filename"
	end

	# synchronized
	def dumpMarkdown
		if @enableGitPathOutput then
			puts "| gitPath | duration | #{get2ndFieldName()} | added | removed |"
			puts "| :--- | :--- | :--- | ---: | ---: |"
		else
			puts "| duration | #{get2ndFieldName()} | added | removed |"
			puts "| :--- | :--- | ---: | ---: |"
		end
		@result.each do |gitPath, result|
			result.each do |duration, result2|
				result2.each do |theResult|
					filename = theResult[:key]
					_result = theResult[:value]
					if @enableGitPathOutput then
						puts "| #{gitPath} | #{duration} | #{filename} | #{_result[:added]} | #{_result[:removed]} |"
					else
						puts "| #{duration} | #{filename} | #{_result[:added]} | #{_result[:removed]} |"
					end
				end
			end
		end
	end

	# synchronized
	def dumpMarkdownPerGit
		if @enableGitPathOutput then
			puts "| gitPath | duration | added | removed |"
			puts "| :--- | ---: | ---: | ---: |"
		else
			puts "| duration | added | removed ||"
			puts "| ---: | ---: | ---: |"
		end
		@result.each do |gitPath, result2|
			result2.each do |duration, result|
				if @enableGitPathOutput then
					puts "| #{gitPath} | #{duration} | #{result[:added]} | #{result[:removed]} |"
				else
					puts "| #{duration} | #{result[:added]} | #{result[:removed]} |"
				end
			end
		end
	end

	# synchronized
	def dumpJson
		puts "{"
		@result.each do |gitPath, result|
			if @enableGitPathOutput then
				puts "  \"#{gitPath}\" : {"
			end
			result.each do |duration, result2|
				puts "    \"#{duration}\" : {"
				result2.each do |theResult|
					filename = theResult[:key]
					_result = theResult[:value]
					puts "      \"#{filename}\" : { \"added\":#{_result[:added]}, \"removed\":#{_result[:removed]} },"
				end
			end
			puts "    }"
			if @enableGitPathOutput then
				puts "  }"
			end
		end
		puts "}"
	end

	# synchronized
	def dumpJsonPerGit
		puts "["
		@result.each do |gitPath, result2|
			result2.each do |duration, result|
				if @enableGitPathOutput then
					puts "  \"#{gitPath}\" : { \"duration\":#{duration}, \"added\":#{result[:added]}, \"removed\":#{result[:removed]} },"
				else
					puts "  { \"duration\":#{duration}, \"added\":#{result[:added]}, \"removed\":#{result[:removed]} },"
				end
			end
		end
		puts "]"
	end

	# synchronized
	def dumpCsv
		@result.each do |gitPath, result2|
			result2.each do |duration, result|
				result.each do |theResult|
					filename = theResult[:key]
					_result = theResult[:value]
					if @enableGitPathOutput then
						puts "\"#{gitPath}\", \"#{duration}\", \"#{filename}\", #{_result[:added]}, #{_result[:removed]}"
					else
						puts "\"#{duration}\", #{filename}\", #{_result[:added]}, #{_result[:removed]}"
					end
				end
			end
		end
	end

	# synchronized
	def dumpCsvPerGit
		@result.each do |gitPath, result2|
			result2.each do |duration, result|
				if @enableGitPathOutput then
					puts "\"#{gitPath}\", \"#{duration}\", #{result[:added]}, #{result[:removed]}"
				else
					puts "\"#{duration}\", #{result[:added]}, #{result[:removed]}"
				end
			end
		end
	end

	# synchronized
	def collectPerGit
		result = {}
		@result.each do |gitPath, result2|
			result2.each do |duration, aResult|
				added = 0
				removed = 0
				aResult.each do | theResult |
					filename = theResult[:key]
					_result = theResult[:value]
					added = added + _result[:added]
					removed = removed + _result[:removed]
				end
				tmp = {}
				if result.has_key?(gitPath) then
					tmp = result[gitPath]
				end
				tmp[duration] = {:added=>added, :removed=>removed}
				result[gitPath] = tmp
			end
		end
		@result = result
	end

	# synchronized
	def sortResult
		result = {}
		@result.each do |gitPath, result2|
			result2.each do |duration, aResult|
				theResult = HashUtil.toArrayFromHash( aResult )			
				case @sort
				when "straight"
					theResult.sort!{|b, a| (a[:value][:added]+a[:value][:removed]) <=> (b[:value][:added]+b[:value][:removed]) }
				when "reverse"
					theResult.sort!{|a, b| (a[:value][:added]+a[:value][:removed]) <=> (b[:value][:added]+b[:value][:removed]) }
				end
				tmp = {}
				if result.has_key?( gitPath ) then
					tmp = result[ gitPath ]
				end
				tmp[duration] = theResult
				tmp = tmp.sort.to_h

				result[gitPath] = tmp
			end
		end
		@result = result
	end

	def report()
		@_mutex.synchronize {
			sortResult()
			case @mode
			when "file",  "author"
				#@result is already per-file then no need to do additionally
				dumpMarkdown() if @outputFormat == "markdown"
				dumpCsv() if @outputFormat == "csv"
				dumpJson() if @outputFormat == "json"
			when "git"
				collectPerGit()
				dumpMarkdownPerGit() if @outputFormat == "markdown"
				dumpCsvPerGit() if @outputFormat == "csv"
				dumpJsonPerGit() if @outputFormat == "json"
			end

		}
	end
end


class ExecGitLogStat < TaskAsync
	COMMIT_SEPARATOR = "#####"

	def initialize(gitPath, resultCollector, duration, gitOptions, options)
		super("ExecGitLogStat::#{gitPath}")
		@gitPath = gitPath
		@resultCollector = resultCollector
		@duration = duration
		@gitOptions = gitOptions
		@options = options
	end

	def execute
		result = {}

		if( FileTest.directory?(@gitPath) ) then
			git_log_result = GitUtil.getLogNumStat(@gitPath, COMMIT_SEPARATOR, @gitOptions);
			if @options[:mode]=="author" then
				result = GitUtil.parseNumStatPerAuthor( git_log_result, COMMIT_SEPARATOR )
			else
				result = GitUtil.parseNumStatPefFile( git_log_result, COMMIT_SEPARATOR )
			end
		else
			puts "\n#{@gitPath} is not existed)" if @options[:verbose]
		end

		@resultCollector.onResult(@gitPath, @duration, result) if !result.empty?
		_doneTask()
	end
end


class GitOptionUtil
	def self.filterAuthor(gitOptions, author)
		if author then
			gitOptions = gitOptions + " --author=#{author}"
		end
		return gitOptions
	end

	def self.getDateStringFromDurationOption(duration)
		result = ""
		if duration.start_with?("from:") then
			pos = duration.index(":")
			result = duration.slice( pos + 1, duration.length - pos - 1 )
		end
		return result
	end

	def self.getDaysFromDuration(duration)
		result = 1
		case duration
		when "day"
			result = 1
		when "month"
			result = 31
		when "year"
			result = 365
		else
			tmp = getDateStringFromDurationOption(duration)
			fromDate = Date.parse(tmp)
			todayDate = Date.today()
			result = todayDate - fromDate
		end
		return result.to_i
	end

	def self.filterDuration(gitOptions, duration)
		if duration then
			case duration
			when "day"
				gitOptions = gitOptions + " --after=\"1 day ago\""
			when "month"
				gitOptions = gitOptions + " --after=\"1 month ago\""
			when "year"
				gitOptions = gitOptions + " --after=\"1 year ago\""
			else
				fromDate = getDateStringFromDurationOption(duration)
				if !fromDate.empty? then
					gitOptions = gitOptions + " --after=#{fromDate}"
				end
			end
		end
		return gitOptions
	end
end



#---- main --------------------------
options = {
	:verbose => false,
	:gitOptions	=> "",
	:outputFormat => "csv",
	:enableGitPathOutput => true,
	:mode => "file",
	:duration => "full",
	:calcUnit => "full",
	:sort => "none",
	:author => nil,
	:numOfThreads => TaskManagerAsync.getNumberOfProcessor(),
}


opt_parser = OptionParser.new do |opts|
	cmds = ""
	opts.banner = "Usage: #{cmds} gitDir1 gitDir2 ..."

	opts.on("-m", "--mode=", "Specify analysis mode: file or git or author(default:#{options[:mode]})") do |mode|
		options[:mode] = mode
	end

	opts.on("-d", "--duration=", "Specify analyzing duration: full, day, month(=last 1 month), year, e.g. from:2021-04-01 (default:#{options[:duration]})") do |duration|
		options[:duration] = duration
	end

	opts.on("-u", "--calcUnit=", "Specify analyzing unit: full, per-day, per-month, per-year (default:#{options[:calcUnit]})") do |calcUnit|
		options[:calcUnit] = calcUnit
	end

	opts.on("-o", "--gitOpt=", "Specify git options --gitOpt='--oneline', etc.") do |gitOptions|
		options[:gitOptions] = gitOptions
	end

	opts.on("", "--outputFormat=", "Specify markdown or csv or json (default:#{options[:outputFormat]})") do |outputFormat|
		outputFormat.strip!
		outputFormat.downcase!
		options[:outputFormat] = outputFormat if outputFormat == "csv" || outputFormat == "markdown" || outputFormat == "json"
	end

	opts.on("-a", "--author=", "Specify author if want to filter with") do |author|
		options[:author] = author
	end

	opts.on("-s", "--sort=", "Specify sort mode: none, straight, reverse (default:#{options[:sort]})") do |sort|
		options[:sort] = sort
	end

	opts.on("", "--disableGitPathOutput", "Specify if you don't want to output gitPath as 1st col.") do |disableGitPathOutput|
		options[:enableGitPathOutput] = false
	end

	opts.on("-j", "--numOfThreads=", "Specify number of threads (default:#{options[:numOfThreads]})") do |numOfThreads|
		options[:numOfThreads] = numOfThreads
	end

	opts.on("-v", "--verbose", "Enable verbose status output (default:#{options[:verbose]})") do
		options[:verbose] = true
	end
end.parse!


# common
taskMan = TaskManagerAsync.new( options[:numOfThreads].to_i )

resultCollector = ResultCollector.new( options[:mode], options[:sort], options[:outputFormat], options[:enableGitPathOutput] )

gitPaths = ARGV.clone()
gitPaths.push(".") if gitPaths.empty?


options[:gitOptions] = GitOptionUtil.filterAuthor(options[:gitOptions], options[:author])
if options[:calcUnit] == "full" then
	options[:gitOptions] = GitOptionUtil.filterDuration(options[:gitOptions], options[:duration])

	gitPaths.each do |aPath|
		taskMan.addTask( ExecGitLogStat.new( aPath, resultCollector, options[:calcUnit], options[:gitOptions], options ) )
	end
else
	fromDate = GitOptionUtil.getDaysFromDuration( options[:duration] )
	calcUnit = ""

	case options[:calcUnit]
	when "per-day"
		calcUnit = "day ago"
		#fromDate is already "day" based
	when "per-month"
		calcUnit = "month ago"
		fromDate = ( (fromDate / 31) + 0.999).to_i
	when "per-year"
		calcUnit = "year ago"
		fromDate = ( (fromDate / 365) + 0.999).to_i
	else
	end

	(1..fromDate).each do |i|
		options[:gitOptions] = "#{options[:gitOptions]} --after=\"#{i} #{calcUnit}\" --before=\"#{i-1} #{calcUnit}\""

		gitPaths.each do |aPath|
			taskMan.addTask( ExecGitLogStat.new( aPath, resultCollector, i, options[:gitOptions], options ) )
		end
	end
end

taskMan.executeAll()
taskMan.finalize()
resultCollector.report()

