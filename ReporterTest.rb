#!/usr/bin/ruby

# Copyright 2024 hidenory
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

require_relative "Reporter"

reporter = XmlReporter2.new(nil)
data = {
	"abc":{
		:added=>1000,
		:removed=>2000
	},
	"def":{
		"hoge":{
			:added=>1000,
			:removed=>2000
		},
		"hoge2":[
			{"hoge":100},
			[100,200],
			200
		]
	},
}
reporter.report(data)

data = [
    {
        "index": "2023-02",
        "added": 3106,
        "removed": 405
    },
    {
        "index": "2023-03",
        "added": 5613,
        "removed": 118
    }
]
reporter.report(data)
