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
	def initialize( outputFormat )
		@result = {}
		@_mutex = Mutex.new
		@outputFormat = outputFormat
	end
	def onResult( gitPath, result )
		@_mutex.synchronize {
			@result[ gitPath ] = result
		}
	end
	def dumpMarkdown
		puts "|| gitPath || filename || added || removed ||"
		@result.each do |gitPath, result|
			result.each do |filename, _result|
				puts "| #{gitPath} | #{filename} | #{_result[:added]} | #{_result[:removed]} |"
			end
		end
	end
	def dumpJson
		puts "{"
		@result.each do |gitPath, result|
			puts "  \"#{gitPath}\" : {"
			result.each do |filename, _result|
				puts "    \"#{filename}\" : { \"added\":#{_result[:added]}, \"removed\":#{_result[:removed]} },"
			end
			puts "  }"
		end
		puts "}"
	end
	def dumpCsv
		@result.each do |gitPath, result|
			result.each do |filename, _result|
				puts "\"#{gitPath}\", \"#{filename}\", #{_result[:added]}, #{_result[:removed]}"
			end
		end
	end
	def report()
		@_mutex.synchronize {
			dumpMarkdown() if @outputFormat == "markdown"
			dumpCsv() if @outputFormat == "csv"
			dumpJson() if @outputFormat == "json"
		}
	end
end


class ExecGitLogStat < TaskAsync
	def initialize(gitPath, resultCollector, options)
		super("ExecGitLogStat::#{gitPath}")
		@gitPath = gitPath
		@resultCollector = resultCollector
		@options = options
	end

	def execute
		result = {}

		if( FileTest.directory?(@gitPath) ) then
			result = GitUtil.getLogNumStat(@gitPath, "#####", @options[:gitOptions]);
		else
			puts "\n#{@gitPath} is not existed)" if @options[:verbose]
		end

		@resultCollector.onResult(@gitPath, result) if !result.empty?
		_doneTask()
	end
end




#---- main --------------------------
options = {
	:verbose => false,
	:gitOptions	=> "",
	:outputFormat => "csv",
	:numOfThreads => TaskManagerAsync.getNumberOfProcessor(),
}


opt_parser = OptionParser.new do |opts|
	cmds = ""
	opts.banner = "Usage: #{cmds} gitDir1 gitDir2 ..."

	opts.on("-j", "--numOfThreads=", "Specify number of threads (default:#{options[:numOfThreads]})") do |numOfThreads|
		options[:numOfThreads] = numOfThreads
	end

	opts.on("-v", "--verbose", "Enable verbose status output (default:#{options[:verbose]})") do
		options[:verbose] = true
	end

	opts.on("-o", "--gitOpt=", "Specify git options --gitOpt='--oneline', etc.") do |gitOptions|
		options[:gitOptions] = gitOptions
	end

	opts.on("", "--outputFormat=", "Specify markdown or csv or json (default:#{options[:outputFormat]})") do |outputFormat|
		outputFormat.strip!
		outputFormat.downcase!
		options[:outputFormat] = outputFormat if outputFormat == "csv" || outputFormat == "markdown" || outputFormat == "json"
	end
end.parse!


# common
taskMan = TaskManagerAsync.new( options[:numOfThreads].to_i )

resultCollector = ResultCollector.new( options[:outputFormat] )

gitPaths = ARGV.clone()
gitPaths.push(".") if gitPaths.empty?

gitPaths.each do |aPath|
	taskMan.addTask( ExecGitLogStat.new( aPath, resultCollector, options ) )
end

taskMan.executeAll()
taskMan.finalize()
resultCollector.report()

