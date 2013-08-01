#!/usr/bin/env python

import ConfigParser
import os
import sys
import gspread

# Read config info
config = ConfigParser.ConfigParser()
config.readfp(open(os.path.expanduser('~/.gcat.conf')))

# Log in
user = config.get('User info', 'user')
password = config.get('User info', 'password')
gc = gspread.login(user, password)

# Read in spreadsheet source info
source_info = ConfigParser.ConfigParser()
source_info.readfp(sys.stdin)
sections = source_info.sections()

def removeNonAscii(s):
        return "".join(filter(lambda x: ord(x) < 128, s))

def cat_tables(section):
        print "=====%s" % section
        for p in source_info.items(section):
                [spreadsheet_key, worksheet_index, col_str] = p[1].split(":")
                spreadsheet = gc.open_by_key(spreadsheet_key)
                worksheet = spreadsheet.get_worksheet(int(worksheet_index))
                col_ids = col_str.split(",")

                cols = [worksheet.col_values(int(i)) for i in col_ids]
                if len(cols) == 0:
                        return
                list_of_lists = []
                max_len = max([len(c) for c in cols])
                for r in range(max_len):
                        row = []
                        for c in range(len(cols)):
                                item = ''
                                if r < len(cols[c]):
                                        item = cols[c][r]
                                if item is None:
                                        item = ''
                                row.append(item)
                        list_of_lists.append(row)

                #list_of_lists = worksheet.get_all_values()
                for row in list_of_lists:
                        print removeNonAscii('\t'.join(row))
        return

# Print out data
for s in sections:
        cat_tables(s)
