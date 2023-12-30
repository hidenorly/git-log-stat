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


def getAddedRemovedOverGits(targetPath, fromYear, author)
	added = 0
	removed = 0
	author = author ? "-a #{author}" : ""
	exec_cmd = "ruby #{File.dirname(File.expand_path(__FILE__))}/git-log-stat.rb -r -m git --duration=\"from:#{fromYear}-01-01\" --gitOpt=\"--before=#{fromYear+1}-01-01\" #{author}"
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
	:fromYear => nil,
	:endYear => nil,
}


opt_parser = OptionParser.new do |opts|
	cmds = ""
	opts.banner = "Usage: #{cmds} gitDirs' root e.g. ~/work"

	opts.on("-a", "--author=", "Specify author if want to filter with") do |author|
		options[:author] = author
	end

	opts.on("-f", "--from=", "Specify from-year") do |fromyear|
		options[:fromYear] = fromyear.to_i
	end

	opts.on("-f", "--end=", "Specify end-year") do |endYear|
		options[:endYear] = endYear.to_i
	end
end.parse!

current_time = Time.now
current_year = current_time.year

options[:fromYear] = current_year if !options[:fromYear]
options[:endYear] = current_year if !options[:endYear]

options[:endYear] = options[:fromYear] if options[:fromYear] > options[:endYear]


(options[:fromYear]..options[:endYear]).each do |year|
	added, removed = getAddedRemovedOverGits(ARGV[0], year, options[:author])
	puts "#{year},#{added},#{removed}"
end
