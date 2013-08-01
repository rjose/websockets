# Use like this: gawk -f planify.awk work.txt > plan.txt
#
# This basically constructs the work item IDs for a plan based on a work.txt
# file. The order in the file corresponds to the ranking.

BEGIN {
        print("ID\tName\tNumWeeks\tTeamId\tCutline\tWorkItems\tTags");
        print("-----");
}

NR > 2 {
        work_items = work_items $1 ",";
        }

END {
        printf("1\tMobileQ3\t13\t0\t200\t%s\t\n",
               substr(work_items, 1, length(work_items) - 1));
}
