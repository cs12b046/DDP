import sys
with open(sys.argv[1]) as f:
	content = f.readlines()
number_of_edge = 0;
number_of_vertex = 0;
for s in content:
	lst = s.split()
	if(s[0] == 'c'):
		continue;
	elif (s[0] == 'p'):
		print int(lst[2]),int(lst[3])
		if int(lst[3]) == 0:
			print "ERROR: Edge weight can't  be zero"
	elif (s[0] == 'a'):
		print int(lst[1])-1,int(lst[2])-1	
