BEGIN   {FS = "\t"}
NR <= 2 {print $0}

NR > 2  {printf("%d\t%s\t%s\t\n", NR-2, $2, $3)}
