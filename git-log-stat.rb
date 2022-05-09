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
end


class ResultCollector
	def initialize( mode, outputFormat, enableGitPathOutput )
		@result = {}
		@_mutex = Mutex.new
		@mode = mode
		@outputFormat = outputFormat
		@enableGitPathOutput = enableGitPathOutput
	end

	def onResult( gitPath, result )
		@_mutex.synchronize {
			@result[ gitPath ] = result
		}
	end

	def get2ndFieldName()
		return "author" if @mode == "author"
		return "filename"
	end

	# synchronized
	def dumpMarkdown
		if @enableGitPathOutput then
			puts "| gitPath | #{get2ndFieldName()} | added | removed |"
			puts "| :--- | :--- | ---: | ---: |"
		else
			puts "| #{get2ndFieldName()} | added | removed |"
			puts "| :--- | ---: | ---: |"
		end
		@result.each do |gitPath, result|
			result.each do |filename, _result|
				if @enableGitPathOutput then
					puts "| #{gitPath} | #{filename} | #{_result[:added]} | #{_result[:removed]} |"
				else
					puts "| #{filename} | #{_result[:added]} | #{_result[:removed]} |"
				end
			end
		end
	end

	# synchronized
	def dumpMarkdownPerGit
		if @enableGitPathOutput then
			puts "| gitPath | added | removed |"
			puts "| :--- | ---: | ---: |"
		else
			puts "| added | removed ||"
			puts "| ---: | ---: |"
		end
		@result.each do |gitPath, result|
			if @enableGitPathOutput then
				puts "| #{gitPath} | #{result[:added]} | #{result[:removed]} |"
			else
				puts "| #{result[:added]} | #{result[:removed]} |"
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
			result.each do |filename, _result|
				puts "    \"#{filename}\" : { \"added\":#{_result[:added]}, \"removed\":#{_result[:removed]} },"
			end
			if @enableGitPathOutput then
				puts "  }"
			end
		end
		puts "}"
	end

	# synchronized
	def dumpJsonPerGit
		puts "["
		@result.each do |gitPath, result|
			if @enableGitPathOutput then
				puts "  \"#{gitPath}\" : {\"added\":#{result[:added]}, \"removed\":#{result[:removed]} },"
			else
				puts "  {\"added\":#{result[:added]}, \"removed\":#{result[:removed]} },"
			end
		end
		puts "]"
	end

	# synchronized
	def dumpCsv
		@result.each do |gitPath, result|
			result.each do |filename, _result|
				if @enableGitPathOutput then
					puts "\"#{gitPath}\", \"#{filename}\", #{_result[:added]}, #{_result[:removed]}"
				else
					puts "\"#{filename}\", #{_result[:added]}, #{_result[:removed]}"
				end
			end
		end
	end

	# synchronized
	def dumpCsvPerGit
		@result.each do |gitPath, result|
			if @enableGitPathOutput then
				puts "\"#{gitPath}\", #{result[:added]}, #{result[:removed]}"
			else
				puts "#{result[:added]}, #{result[:removed]}"
			end
		end
	end

	# synchronized
	def collectPerGit
		result = {}
		@result.each do |gitPath, aResult|
			added = 0
			removed = 0
			aResult.each do |filename, _result|
				added = added + _result[:added]
				removed = removed + _result[:removed]
			end
			result[gitPath] = {:added=>added, :removed=>removed}
		end
		@result = result
	end

	def report()
		@_mutex.synchronize {
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

	def initialize(gitPath, resultCollector, options)
		super("ExecGitLogStat::#{gitPath}")
		@gitPath = gitPath
		@resultCollector = resultCollector
		@options = options
	end

	def execute
		result = {}

		if( FileTest.directory?(@gitPath) ) then
			git_log_result = GitUtil.getLogNumStat(@gitPath, COMMIT_SEPARATOR, @options[:gitOptions]);
			if @options[:mode]=="author" then
				result = GitUtil.parseNumStatPerAuthor( git_log_result, COMMIT_SEPARATOR )
			else
				result = GitUtil.parseNumStatPefFile( git_log_result, COMMIT_SEPARATOR )
			end
		else
			puts "\n#{@gitPath} is not existed)" if @options[:verbose]
		end

		@resultCollector.onResult(@gitPath, result) if !result.empty?
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
end



#---- main --------------------------
options = {
	:verbose => false,
	:gitOptions	=> "",
	:outputFormat => "csv",
	:enableGitPathOutput => true,
	:mode => "file",
	:author => nil,
	:numOfThreads => TaskManagerAsync.getNumberOfProcessor(),
}


opt_parser = OptionParser.new do |opts|
	cmds = ""
	opts.banner = "Usage: #{cmds} gitDir1 gitDir2 ..."

	opts.on("-m", "--mode=", "Specify analysis mode: file or git or author(default:#{options[:mode]})") do |mode|
		options[:mode] = mode
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

resultCollector = ResultCollector.new( options[:mode], options[:outputFormat], options[:enableGitPathOutput] )

gitPaths = ARGV.clone()
gitPaths.push(".") if gitPaths.empty?


options[:gitOptions] = GitOptionUtil.filterAuthor(options[:gitOptions], options[:author])

gitPaths.each do |aPath|
	taskMan.addTask( ExecGitLogStat.new( aPath, resultCollector, options ) )
end

taskMan.executeAll()
taskMan.finalize()
resultCollector.report()

