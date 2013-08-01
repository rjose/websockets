BEGIN   {FS = "\t";
	printf("ID\tName\tSkills\tTags\n");
	printf("-----\n");
	id = 1;
}

NR <= 2 	{next}

$1 != "" 	{ skill = $1; 
                  if (skill == "Server")
                        skill = "Apps"
                }

$2 != "" && $2 !~ /HOLE/  	{ printf("%d\t%s\t%s:1\t%s\n", id++, $2, skill, "track:Mobilize") }
$3 != "" && $3 !~ /HOLE/ 	{ printf("%d\t%s\t%s:1\t%s\n", id++, $3, skill, "track:Felix") }
$4 != "" && $4 !~ /HOLE/ 	{ printf("%d\t%s\t%s:1\t%s\n", id++, $4, skill, "track:Tablet") }
$5 != "" && $5 !~ /HOLE/ 	{ printf("%d\t%s\t%s:1\t%s\n", id++, $5, skill, "track:Contacts") }
$6 != "" && $6 !~ /HOLE/ 	{ printf("%d\t%s\t%s:1\t%s\n", id++, $6, skill, "track:Rapportive") }
$7 != "" && $7 !~ /HOLE/ 	{ printf("%d\t%s\t%s:1\t%s\n", id++, $7, skill, "track:Soprano") }
$8 != "" && $8 !~ /HOLE/ 	{ printf("%d\t%s\t%s:1\t%s\n", id++, $8, skill, "track:Money") }
$9 != "" && $9 !~ /HOLE/ 	{ printf("%d\t%s\t%s:1\t%s\n", id++, $9, skill, "track:Austin") }
