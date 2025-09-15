#!/usr/bin/env python
import random
from collections  import defaultdict as dd

n = 4
s = ""
cntr = dd(int)

for randcnt in range(100000):
	perm = range(n)
	for permcnt in range(n):
		i = random.randint(0,n-1)
		j = random.randint(0,n-1)
		
#		i = permcnt
#		j = random.randint(permcnt,n-1)

		tmp=perm[i]
		perm[i] = perm[j]
		perm[j] = tmp

		
	
	out = s.join("%d"%x for x in perm)
	cntr[out] += 1
	
for perm in sorted(cntr.keys()):
	print("%s %d"%(perm,cntr[perm]))