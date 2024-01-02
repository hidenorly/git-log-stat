#!/usr/bin/ruby

# Copyright 2023 hidenory
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
require_relative "ExecUtil"

def getAddedRemovedOverGits(targetPath, from, delta, gitOptions = nil, author = nil)
	added = 0
	removed = 0
	author = author ? "-a #{author}" : ""
	exec_cmd = "ruby #{File.dirname(File.expand_path(__FILE__))}/git-log-stat.rb -r -m git --duration=\"from:#{from.strftime("%Y-%m-%d")}\" --gitOpt=\"--before=#{(from + delta).strftime("%Y-%m-%d")} #{gitOptions}\" #{author}"
	result = ExecUtil.getExecResultEachLine(exec_cmd, targetPath)
	result.each do |aLine|
		data = aLine.split(",")
		if data.length == 4 then
			added += data[2].to_i
			removed += data[3].to_i
		end
	end
	return added, removed
end


#---- main --------------------------
options = {
	:verbose => false,
	:gitOptions	=> "",
	:outputFormat => "csv",
	:author => nil,
	:colllectionUnit => "year",
	:from => nil,
	:end => nil,
}


opt_parser = OptionParser.new do |opts|
	cmds = ""
	opts.banner = "Usage: #{cmds} gitDirs' root e.g. ~/work"

	opts.on("-a", "--author=", "Specify author if want to filter with") do |author|
		options[:author] = author
	end

	opts.on("-u", "--collectionUnit=", "Specify collection unit year or month or day default:#{options[:colllectionUnit]}") do |colllectionUnit|
		colllectionUnit.downcase!
		case colllectionUnit
		when "month", "year", "day"
			options[:colllectionUnit] = colllectionUnit
		else
			options[:colllectionUnit] = "year"
		end
	end

	opts.on("-f", "--from=", "Specify from e.g. 2023 or 2023-01 or 2023-01-01") do |from|
		options[:from] = from
	end

	opts.on("-e", "--end=", "Specify end e.g. 2023 or 2023-12 or 2023-12-31") do |it|
		options[:end] = it
	end

	opts.on("-g", "--gitOpt=", "Specify additional git options") do |gitOptions|
		options[:gitOptions] = gitOptions
	end
end.parse!

current_time = Time.now
current_year = current_time.year

options[:from] = current_year if !options[:from]
options[:end] = current_year if !options[:end]

if ARGV.length == 1 then
	currentDate = nil
	endDate = nil
	begin
		currentDate = Date.strptime( options[:from].to_s, "%Y-%m-%d" )
		endDate = Date.strptime( options[:end].to_s, "%Y-%m-%d" )
	rescue ArgumentError
		begin
			currentDate = Date.strptime( options[:from].to_s, "%Y-%m" )
			endDate = Date.strptime( options[:end].to_s, "%Y-%m" )
		rescue ArgumentError
			currentDate = Date.strptime( options[:from].to_s, "%Y" )
			endDate = Date.strptime( options[:from].to_s, "%Y" )
		end
	end

	endDate = currentDate if currentDate > endDate

	delta = options[:colllectionUnit] == "year" ? 365 : options[:colllectionUnit] == "month" ? 12 : 1

	while currentDate <= endDate
		added, removed = getAddedRemovedOverGits(ARGV[0], currentDate, delta, options[:gitOptions], options[:author])
		theIndex = options[:colllectionUnit] == "year" ? currentDate.strftime("%Y") : options[:colllectionUnit] == "month" ? currentDate.strftime("%Y-%m") : currentDate.strftime("%Y-%m-%d")
		puts "#{theIndex},#{added},#{removed}"
		currentDate = currentDate + delta
	end
end