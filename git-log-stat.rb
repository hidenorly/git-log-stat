#!/usr/bin/ruby

# Copyright 2022, 2023, 2025 hidenory
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
require 'rexml/document'
require_relative "TaskManager"
require_relative "FileUtil"
require_relative "StrUtil"
require_relative "ExecUtil"
require_relative "GitUtil"


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
	def initialize( mode, sort, sortKey, outputFormat, enableGitPathOutput, enableDurationOutput, countMax=nil )
		@result = {}
		@_mutex = Mutex.new
		@mode = mode
		@sort = sort
		@sortKey = sortKey
		@outputFormat = outputFormat
		@enableGitPathOutput = enableGitPathOutput
		@enableDurationOutput = enableDurationOutput
		@countMax = countMax
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

	def getMarkdownFieldNameFormat()
		fieldName = ""
		fieldFormat = ""
		if @enableGitPathOutput then
			fieldName = "| gitPath #{fieldName}"
			fieldFormat = "| :--- #{fieldFormat}"
		end
		if @enableDurationOutput then
			fieldName = "#{fieldName} | duration"
			fieldFormat = "#{fieldFormat} | :--- "
		end

		return fieldName, fieldFormat
	end

	# synchronized
	def dumpMarkdown
		fieldName, fieldFormat = getMarkdownFieldNameFormat()
		puts "#{fieldName}| #{get2ndFieldName()} | added | removed |"
		puts "#{fieldFormat}| :--- | ---: | ---: |"

		@result.each do |gitPath, result|
			result.each do |duration, result2|
				result2.each do |filename, _result|
					print("| #{gitPath} ") if @enableGitPathOutput
					print("| #{duration} ") if @enableDurationOutput
					print "| #{filename} | #{_result[:added]} | #{_result[:removed]} |\n"
				end
			end
		end
	end

	# synchronized
	def dumpMarkdownPerGit
		fieldName, fieldFormat = getMarkdownFieldNameFormat()
		puts "#{fieldName}| added | removed |"
		puts "#{fieldFormat}| ---: | ---: |"
		@result.each do |gitPath, result2|
			result2.each do |duration, _result|
				print("| #{gitPath} ") if @enableGitPathOutput
				print("| #{duration} ") if @enableDurationOutput
				print "| #{_result[:added]} | #{_result[:removed]} |\n"
			end
		end
	end

	# synchronized
	def dumpMarkdownPerDuration
		fieldName = ""
		fieldFormat = ""
		if @enableGitPathOutput then
			fieldName = " | gitPath"
			fieldFormat = " | :---"
		end

		puts "| duration#{fieldName} | added | removed |"
		puts "| ---:#{fieldFormat} | ---: | ---: |"
		@result.each do |duration, result2|
			if @enableGitPathOutput
				result2.each do |gitPath, _result|
					puts "| #{duration} | #{gitPath} | #{_result[:added]} | #{_result[:removed]} |"
				end
			else
				added = 0
				removed = 0
				result2.each do |gitPath, _result|
					 added = added + _result[:added]
					 removed = removed + _result[:removed]
				end
				puts "| #{duration} | #{added} | #{removed} |"
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
				puts "    \"#{duration}\" : {" if @enableDurationOutput
				result2.each do |filename, _result|
					puts "      \"#{filename}\" : { \"added\":#{_result[:added]}, \"removed\":#{_result[:removed]} },"
				end
			end
			puts "    }" if @enableDurationOutput
			puts "  }" if @enableGitPathOutput
		end
		puts "}"
	end

	# synchronized
	def dumpJsonPerGit
		puts "["
		@result.each do |gitPath, result2|
			result2.each do |duration, result|
				print("  \"#{gitPath}\" : { ") if @enableGitPathOutput
				if @enableDurationOutput
					print("\"duration\":#{duration}, \"added\":#{result[:added]}, \"removed\":#{result[:removed]} },\n")
				else
					print("\"added\":#{result[:added]}, \"removed\":#{result[:removed]} },\n")
				end
			end
		end
		puts "]"
	end

	# synchronized
	def dumpJsonPerDuration
		puts "["
		@result.each do |duration, result2|
			if @enableGitPathOutput
				puts "  { \"#{duration}\" : {"
				result2.each do |gitPath, _result|
					puts "    \"#{gitPath}\" : { \"added\":#{_result[:added]}, \"removed\":#{_result[:removed]} },"
				end
				puts "  }},"
			else
				added = 0
				removed = 0
				result2.each do |gitPath, _result|
					 added = added + _result[:added]
					 removed = removed + _result[:removed]
				end
				puts "  {\"duration\":\"#{duration}\", \"added\":#{added}, \"removed\":#{removed} },"
			end
		end
		puts "]"
	end


	# synchronized
	def dumpCsv
		@result.each do |gitPath, result2|
			result2.each do |duration, result|
				result.each do |filename, _result|
					print("\"#{gitPath}\", ") if @enableGitPathOutput
					print("\"#{duration}\", ") if @enableDurationOutput
					print("\"#{filename}\", #{_result[:added]}, #{_result[:removed]}\n")
				end
			end
		end
	end

	# synchronized
	def dumpCsvPerGit
		@result.each do |gitPath, result2|
			result2.each do |duration, result|
				print("\"#{gitPath}\", ") if @enableGitPathOutput
				print("\"#{duration}\", ") if @enableDurationOutput
				print("#{result[:added]}, #{result[:removed]}\n")
			end
		end
	end

	# synchronized
	def dumpCsvPerDuration
		@result.each do |duration, result2|
			if @enableGitPathOutput
				result2.each do |gitPath, _result|
					puts "#{duration}, \"#{gitPath}\", #{_result[:added]}, #{_result[:removed]}"
				end
			else
				added = 0
				removed = 0
				result2.each do |gitPath, _result|
					 added = added + _result[:added]
					 removed = removed + _result[:removed]
				end
				puts "#{duration}, #{added}, #{removed}"
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
				aResult.each do | filename, _result |
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
	def collectPerDuration
		result = {}

		@result.each do |gitPath, result2|
			result2.each do |duration, aResult|
				tmp = {}
				tmp = result[duration] if result.has_key?( duration )

				added = 0
				removed = 0
				aResult.each do | filename, _result |
					added = added + _result[:added]
					removed = removed + _result[:removed]
				end
				tmp[gitPath] = {:added=>added, :removed=>removed}

				result[duration] = tmp
			end
		end

		case @sortKey
		when "largestUnit"
			case @sort
			when "straight"
				result = result.sort{|(bKey,b), (aKey,a)| (ResultCollector._calcAllOfAddedRemoved(a) <=> ResultCollector._calcAllOfAddedRemoved(b)) }
			when "reverse"
				result = result.sort{|(aKey,a), (bKey,b)| (ResultCollector._calcAllOfAddedRemoved(a) <=> ResultCollector._calcAllOfAddedRemoved(b)) }
			end
		else
			case @sort
			when "straight"
				result = result.sort{|(bKey,b), (aKey,a)| (aKey.to_i <=> bKey.to_i) }
			when "reverse"
				result = result.sort{|(aKey,a), (bKey,b)| (aKey.to_i <=> bKey.to_i) }
			end
		end

		@result = result
	end

	def self._calcAllOfAddedRemoved(a)
		result = 0
		a.each do |filename, value|
			result = result + value[:added] + value[:removed]
		end
		return result
	end

	def self._calcAllOfAddedRemovedOverDurations(a)
		result = 0
		a.each do |duration, aResult|
			result = result + _calcAllOfAddedRemoved(aResult)
		end
		return result
	end

	# synchronized
	def sortResult
		result = {}
		@result.each do |gitPath, result2|
			result2.each do |duration, aResult|
				# sort files
				case @sort
				when "straight"
					aResult = aResult.sort{|(bKey,b), (aKey,a)| (a[:added]+a[:removed]) <=> (b[:added]+b[:removed]) }
				when "reverse"
					aResult = aResult.sort{|(aKey,a), (bKey,b)| (a[:added]+a[:removed]) <=> (b[:added]+b[:removed]) }
				end
				tmp = {}
				if result.has_key?( gitPath ) then
					tmp = result[ gitPath ]
				end
				if @countMax!=nil then
					aResult = aResult.take(@countMax.to_i)
				end
				tmp[duration] = aResult
				result[gitPath] = tmp
			end

			# sort durations
			tmp = result[gitPath]
			case @sortKey
			when "largestUnit"
				case @sort
				when "straight"
					tmp = tmp.sort{|(bKey, b), (aKey, a)|( ResultCollector._calcAllOfAddedRemoved(a) <=> ResultCollector._calcAllOfAddedRemoved(b) )}
				when "reverse"
					tmp = tmp.sort{|(aKey, a), (bKey, b)|( ResultCollector._calcAllOfAddedRemoved(a) <=> ResultCollector._calcAllOfAddedRemoved(b) )}
				end
			else
				tmp = tmp.sort
			end
			result[gitPath] = tmp
		end

		# sort gitPath(s)
		if @sortKey == "largestGit" then
			case @sort
			when "straight"
				result = result.sort{|(bKey, b), (aKey, a)|( ResultCollector._calcAllOfAddedRemovedOverDurations(a) <=> ResultCollector._calcAllOfAddedRemovedOverDurations(b) )}
			when "reverse"
				result = result.sort{|(aKey, a), (bKey, b)|( ResultCollector._calcAllOfAddedRemovedOverDurations(a) <=> ResultCollector._calcAllOfAddedRemovedOverDurations(b) )}
			end
		else
			result = result.sort{|(aKey, a), (bKey, b)|( aKey.downcase() <=> bKey.downcase() )}
		end
		@result = result
	end

	def report()
		@_mutex.synchronize {
			case @mode
			when "file",  "author"
				sortResult()
				dumpMarkdown() if @outputFormat == "markdown"
				dumpCsv() if @outputFormat == "csv"
				dumpJson() if @outputFormat == "json"
			when "git"
				sortResult()
				collectPerGit()
				dumpMarkdownPerGit() if @outputFormat == "markdown"
				dumpCsvPerGit() if @outputFormat == "csv"
				dumpJsonPerGit() if @outputFormat == "json"
			when "duration"
				collectPerDuration()
				dumpMarkdownPerDuration() if @outputFormat == "markdown"
				dumpCsvPerDuration() if @outputFormat == "csv"
				dumpJsonPerDuration() if @outputFormat == "json"
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
			git_log_result = GitUtil.getLogNumStat(@gitPath, COMMIT_SEPARATOR, @gitOptions, @options[:authorEmail]);
			if @options[:mode]=="author" then
				result = GitUtil.parseNumStatPerAuthor( git_log_result, COMMIT_SEPARATOR )
			else
				result = GitUtil.parseNumStatPerFile( git_log_result, COMMIT_SEPARATOR )
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
		when "full"
			result = 365*5 #TODO: Fix this. this is tentative
		else
			tmp = getDateStringFromDurationOption(duration)
			if !tmp.empty? then
				fromDate = Date.parse(tmp)
				todayDate = Date.today()
				result = todayDate - fromDate
			end
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

class RepoUtil
	DEF_REPOPATH = "/.repo"

	DEF_MANIFESTPATH = "#{DEF_REPOPATH}/manifests"
	DEF_MANIFESTFILE = "manifest.xml"
	DEF_MANIFESTFILE2 = DEF_MANIFESTFILE
	DEF_MANIFESTFILE_DIRS = [
		"/.repo/",
		"/.repo/manifests/"
	]

	def self.isRepoDirectory?(basePath)
		return Dir.exist?(basePath + DEF_MANIFESTPATH)
	end

	def self.getAvailableManifestPath(basePath, manifestFilename)
		DEF_MANIFESTFILE_DIRS.each do |aDir|
			path = basePath + aDir.to_s + manifestFilename
			if FileTest.exist?(path) then
				return path
			end
		end
		return nil
	end

	def self.getPathesFromManifestSub(basePath, manifestFilename, pathGitPath, pathFilter, groupFilter)
		manifestPath = getAvailableManifestPath(basePath, manifestFilename)
		if manifestPath && FileTest.exist?(manifestPath) then
			doc = REXML::Document.new(open(manifestPath))
			doc.elements.each("manifest/include[@name]") do |anElement|
				getPathesFromManifestSub(basePath, anElement.attributes["name"], pathGitPath, pathFilter, groupFilter)
			end
			doc.elements.each("manifest/project[@path]") do |anElement|
				thePath = anElement.attributes["path"].to_s
				theGitPath = anElement.attributes["name"].to_s
				if pathFilter.empty? || ( !pathFilter.to_s.empty? && thePath.match( pathFilter.to_s ) ) then
					theGroups = anElement.attributes["groups"].to_s
					if theGroups.empty? || groupFilter.empty? || ( !groupFilter.to_s.empty? && theGroups.match( groupFilter.to_s ) ) then
						pathGitPath[thePath] = theGitPath
					end
				end
			end
		end
	end

	def self.getPathesFromManifest(basePath, pathFilter="", groupFilter="")
		pathGitPath = {}

		getPathesFromManifestSub(basePath, DEF_MANIFESTFILE, pathGitPath, pathFilter, groupFilter)

		pathes = []
		pathGitPath.keys.each do |aPath|
			pathes << "#{basePath}/#{aPath}"
		end

		return pathes, pathGitPath
	end


	def self.getGitPathesFromManifest(basePath, manifestFile=DEF_MANIFESTFILE2)
		pathGitPath = {}
		getPathesFromManifestSub(basePath, manifestFile, pathGitPath, "", "")

		return pathGitPath
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
	:sort => "straight",
	:sortKey => "largestFile",
	:author => nil,
	:authorEmail => false,
	:recursive => false,
	:countMax => nil,
	:numOfThreads => TaskManagerAsync.getNumberOfProcessor(),
}


opt_parser = OptionParser.new do |opts|
	cmds = ""
	opts.banner = "Usage: #{cmds} gitDir1 gitDir2 ..."

	opts.on("-m", "--mode=", "Specify analysis mode: file or git or author or duration (default:#{options[:mode]})") do |mode|
		options[:mode] = mode
	end

	opts.on("-d", "--duration=", "Specify analyzing duration: full, day, month(=last 1 month), year, e.g. from:2021-04-01 (default:#{options[:duration]})") do |duration|
		options[:duration] = duration
	end

	opts.on("-u", "--calcUnit=", "Specify analyzing unit: full, per-day, per-month, per-year (default:#{options[:calcUnit]})") do |calcUnit|
		options[:calcUnit] = calcUnit
	end

	opts.on("-g", "--gitOpt=", "Specify git options --gitOpt='--oneline', etc.") do |gitOptions|
		options[:gitOptions] = gitOptions
	end

	opts.on("-o", "--outputFormat=", "Specify markdown or csv or json (default:#{options[:outputFormat]})") do |outputFormat|
		outputFormat.strip!
		outputFormat.downcase!
		options[:outputFormat] = outputFormat if outputFormat == "csv" || outputFormat == "markdown" || outputFormat == "json"
	end

	opts.on("-a", "--author=", "Specify author if want to filter with") do |author|
		options[:author] = author
	end

	opts.on("-ae", "--authorEmail", "Enable to output email as author (default:#{options[:authorEmail]})") do
		options[:authorEmail] = true
	end

	opts.on("-s", "--sort=", "Specify sort mode: none, straight, reverse (default:#{options[:sort]})") do |sort|
		options[:sort] = sort
	end

	opts.on("-k", "--sortKey=", "Specify sort key: largestUnit, largestFile, largestGit (default:#{options[:sortKey]})") do |sortKey|
		options[:sortKey] = sortKey
	end

	opts.on("-n", "--countMax=", "Specify output max count if you want to limit") do |countMax|
		options[:countMax] = countMax
	end

	opts.on("", "--disableGitPathOutput", "Specify if you don't want to output gitPath as 1st col.") do |disableGitPathOutput|
		options[:enableGitPathOutput] = false
	end

	opts.on("-j", "--numOfThreads=", "Specify number of threads (default:#{options[:numOfThreads]})") do |numOfThreads|
		options[:numOfThreads] = numOfThreads
	end

	opts.on("-r", "--recursive", "Specify recursive enumeration level (default:#{options[:recursive]})") do
		options[:recursive] = true
	end

	opts.on("-v", "--verbose", "Enable verbose status output (default:#{options[:verbose]})") do
		options[:verbose] = true
	end
end.parse!


# common
taskMan = TaskManagerAsync.new( options[:numOfThreads].to_i )

resultCollector = ResultCollector.new( options[:mode], options[:sort], options[:sortKey], options[:outputFormat], options[:enableGitPathOutput], (options[:duration] != "full" || options[:calcUnit]!="full"), options[:countMax] )

gitPaths = ARGV.clone()
gitPaths.push(".") if gitPaths.empty?

_gitPaths = []
gitPaths.each do |aGitPath|
	gitPathsInManifest = RepoUtil.getGitPathesFromManifest( aGitPath )
	if !gitPathsInManifest.empty? then
		gitPathsInManifest.each do |relative_path, git_path|
		   _gitPaths << "#{aGitPath}/#{relative_path}"
		end
	else
		_gitPaths << aGitPath
	end
end
gitPaths = _gitPaths

if options[:recursive] then
	_gitPath = []
	gitPaths.each do |aPath|
		paths = []
		FileUtil.iteratePath(aPath, "", paths, true, true)
		paths.each do |aCandidatePath|
			if GitUtil.isGitDirectory( aCandidatePath ) then
				_gitPath << aCandidatePath
			end
		end
	end
	gitPaths = _gitPath if !_gitPath.empty?
end

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
	when "per-year", "full"
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

