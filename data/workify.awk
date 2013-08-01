# Use like this: gawk -f workify.awk input.txt > work.txt
#
# This takes data that was exported as text from a spreadsheet like
# link:https://docs.google.com/spreadsheet/ccc?key=0AvCMfDyA42UTdFJldVh0dkREWjBzSHdwbVZMR0luekE#gid=15[this]
# and converts it into a work file that we can import.

BEGIN {
        FS = "\t";
        print("ID\tName\tEstimate\tTriage\tTags");
        print("-----");
}

NR > 1        {printf("%d\t%s\tNative:%s,Web:%s,Apps:%s\t"\
               "ProdTriage:%s,EngTriage:%s,Triage:%s\ttrack:%s,Description:%s,"\
               "RequestingTeam:%s,Dependencies:%s,Notes:%s\n",\
                          NR-1, $5, $10, $11, $12,\
                          $1, $2, $3, $4, $6,\
                          $7, $8, $13)}
