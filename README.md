# git-log-stat

This script enables you to analyze git log statistics easily with your expected formats such as markdown, csv and json.

## Basic usage : per-file analysis

```
% ruby git-log-stat.rb . --outputFormat=markdown
| gitPath | filename | added | removed |
| :--- | :--- | ---: | ---: |
| . | git-log-stat.rb | 645 | 179 |
| . | GitUtil.rb | 218 | 8 |
| . | TaskManager.rb | 177 | 0 |
| . | .gitignore | 59 | 0 |
| . | ExecUtil.rb | 64 | 0 |
| . | FileUtil.rb | 220 | 0 |
| . | StrUtil.rb | 21 | 0 |
| . | LICENSE | 201 | 0 |
| . | README.md | 1 | 0 |
```

You can also specify multiple gits as ```% ruby git-log-stat.rb ~/work/pj1 ~/work/pj2 ~/work/pj3```.
Note that ```~/work/pj1```, ```~/work/pj2``` and ```~/work/pj3``` are .git managed directory.


## Usage : per-git analysis

```
% ruby git-log-stat.rb . --outputFormat=json --mode=git
[
  "." : { "added":1606, "removed":187 },
]
```

## Usage : activity ranking with filename as markdonw

```
% ruby git-log-stat.rb . --outputFormat=markdown --sortKey=largestUnit --calcUnit=per-day --sort=straight --disableGitPathOutput
 | duration| filename | added | removed |
 | :--- | :--- | ---: | ---: |
| 16 | FileUtil.rb | 220 | 0 |
| 16 | LICENSE | 201 | 0 |
| 16 | ExecUtil.rb | 64 | 0 |
| 16 | .gitignore | 59 | 0 |
| 16 | StrUtil.rb | 21 | 0 |
| 16 | README.md | 1 | 0 |
| 14 | TaskManager.rb | 177 | 0 |
| 14 | git-log-stat.rb | 124 | 0 |
| 14 | GitUtil.rb | 1 | 1 |
| 3 | git-log-stat.rb | 157 | 70 |
| 8 | git-log-stat.rb | 100 | 14 |
| 8 | GitUtil.rb | 5 | 5 |
| 15 | GitUtil.rb | 107 | 0 |
| 11 | GitUtil.rb | 66 | 1 |
| 11 | git-log-stat.rb | 9 | 3 |
| 2 | git-log-stat.rb | 36 | 35 |
| 5 | git-log-stat.rb | 52 | 9 |
| 6 | GitUtil.rb | 39 | 1 |
| 6 | git-log-stat.rb | 14 | 5 |
| 1 | git-log-stat.rb | 36 | 20 |
| 10 | git-log-stat.rb | 39 | 13 |
| 9 | git-log-stat.rb | 29 | 7 |
| 4 | git-log-stat.rb | 32 | 3 |
| 7 | git-log-stat.rb | 17 | 0 |
```

duration=16 means 16 days a go.


## Usage : activity ranking as markdown

```
% ruby git-log-stat.rb . --outputFormat=markdown --sortKey=largestUnit --calcUnit=per-day --sort=straight --disableGitPathOutput --mode=git
 | duration| added | removed |
 | :--- | ---: | ---: |
| 16 | 566 | 0 |
| 14 | 302 | 1 |
| 3 | 157 | 70 |
| 8 | 105 | 19 |
| 15 | 107 | 0 |
| 11 | 75 | 4 |
| 2 | 36 | 35 |
| 5 | 52 | 9 |
| 6 | 53 | 6 |
| 1 | 36 | 20 |
| 10 | 39 | 13 |
| 9 | 29 | 7 |
| 4 | 32 | 3 |
| 7 | 17 | 0 |
```

16 days ago is most active day in the git.

## Usage : activity ranking as csv

```
% ruby git-log-stat.rb . --outputFormat=csv --sortKey=largestUnit --calcUnit=per-day --sort=straight --disableGitPathOutput --mode=git
"16", 566, 0
"14", 302, 1
"3", 157, 70
"8", 105, 19
"15", 107, 0
"11", 75, 4
"2", 36, 35
"5", 52, 9
"6", 53, 6
"1", 36, 20
"10", 39, 13
"9", 29, 7
"4", 32, 3
"7", 17, 0
```

## Usage : active git ranking as csv

```
% ruby git-log-stat.rb --outputFormat=csv --sortKey=largestGit  --sort=straight . ~/work/audioframework --mode=git
"audioframework", 27856, 8228
".", 1682, 238
```

## Usage : per-author ranking as markdown

```
% ruby git-log-stat.rb --outputFormat=markdown --sortKey=largestGit  --sort=straight  --mode=author .
| gitPath | author | added | removed |
| :--- | :--- | ---: | ---: |
| . | hidenorly | 1682 | 238 |
```

## Usage : per-git ranking with --author as markdown

```
% ruby git-log-stat.rb --outputFormat=markdown --sortKey=largestGit --sort=straight --mode=git . ~/work/android/s --author="xxx.com"
| gitPath | added | removed |
| :--- | ---: | ---: |
| ~/work/android/s/frameworks/base | 24097 | 6807 |
| ~/work/android/s/cts | 9982 | 1664 |
| ~/work/android/s/device/sample | 4710 | 4728 |
| ~/work/android/s/external/libldac | 8925 | 10 |
..snip..
```

## Usage : per-duration & per-git analysis with --author as csv

```
% ruby git-log-stat.rb --mode=duration --calcUnit=per-month --duration=from:2021-1-1 ~/work/android/s --author="xxxx.com" --outputFormat=csv
16, "/Users/harold/work/android/s/frameworks/base", 265, 12
16, "/Users/harold/work/android/s/cts", 51, 5
16, "/Users/harold/work/android/s/frameworks/native", 448, 6
16, "/Users/harold/work/android/s/frameworks/opt/telephony", 107, 0
..snip..
```

## Usage : per-duration analysis with --author as csv

```
% ruby git-log-stat.rb --mode=duration --calcUnit=per-month --duration=from:2021-1-1 ~/work/android/s --author="xxxx.com" --disableGitPathOutput --outputFormat=csv
16, 884, 24
15, 15, 6
14, 4810, 4775
13, 256, 33
12, 156, 10
11, 13, 3
10, 1, 1
```

## Usage : per-duration active analysis with --author as json

```
% ruby git-log-stat.rb --mode=duration --calcUnit=per-month --duration=from:2021-1-1 ~/work/android/s --author="xxxx.com" --disableGitPathOutput --outputFormat=json --sort=straight --sortKey=largestUnit
[
  {"duration":"14", "added":4810, "removed":4775 },
  {"duration":"16", "added":884, "removed":24 },
  {"duration":"13", "added":256, "removed":33 },
  {"duration":"12", "added":156, "removed":10 },
  {"duration":"15", "added":15, "removed":6 },
  {"duration":"11", "added":13, "removed":3 },
  {"duration":"10", "added":1, "removed":1 },
]
```

## Usage : per-duration active analysis for multiple gits

```
% ruby git-log-stat.rb --mode=duration --calcUnit=per-day --duration=from:2021-04-15  --outputFormat=csv --sort=straight --sortKey=largestFile -r ~/work/github --disableGitPathOutput
```

# git-log-stat-over-gits.rb

This tool can report the statistics of added/removed lines in specified duration over gits.
Note that this tool enumerates the gits under the specified path.

## Usage : duration year

```
ruby git-log-stat-over-gits.rb -f 2022-01-01 -e 2023-12-31 -u year ~/work/github -a hidenorly
2022,34260,5704
2023,35717,2673
```

## Usage : duration month

```
% ruby git-log-stat-over-gits.rb -f 2023-12 -e 2024-01 -u month ~/work/github
```

## Usage : duration day

```
% ruby git-log-stat-over-gits.rb -f 2023-12-01 -e 2024-01-01 -u day ~/work/github
```



# TODOs

* [done] Add csv output
* [done] Add json output
* [done] Add markdown output
* [done] Add --disableGitPathOutput
* [done] Add mode: per-git option
* [] Add mode: per-commit option
* [done] Add mode: statistics option
     * [done] Add mode: statistics option w/per-day, per-month, per-year
        * [done] Add support for --duration=from:xxxx-xx-xx
     * [done] Add mode: statistics option w/per-author
     * [done] Add mode: statistics option w/per-git
* [done] Add filter option --author
* [done] Add Android Manifest support
* [done] Add --sort option

