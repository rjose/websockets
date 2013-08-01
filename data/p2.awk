BEGIN   {FS = "\t";
	printf("ID\tName\tSkills\tTags\n");
	printf("-----\n");
	id = 1;
}

NR == 1 	{next}

$1 != "" 	{ skill = $1 }

$2 != "" 	{ printf("%d\t%s\t%s:1\t\n", id++, $2, skill) }
$3 != "" 	{ printf("%d\t%s\t%s:1\t\n", id++, $3, skill) }
$4 != "" 	{ printf("%d\t%s\t%s:1\t\n", id++, $4, skill) }
$5 != "" 	{ printf("%d\t%s\t%s:1\t\n", id++, $5, skill) }
$6 != "" 	{ printf("%d\t%s\t%s:1\t\n", id++, $6, skill) }
$7 != "" 	{ printf("%d\t%s\t%s:1\t\n", id++, $7, skill) }
$8 != "" 	{ printf("%d\t%s\t%s:1\t\n", id++, $8, skill) }
$9 != "" 	{ printf("%d\t%s\t%s:1\t\n", id++, $9, skill) }
