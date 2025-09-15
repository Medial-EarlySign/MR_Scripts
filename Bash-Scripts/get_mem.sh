#!/bin/bash

#MEM_USE=$(free | egrep "Mem:" | awk '{print int(10*$3/1024/1024)/10}')
#MEM_FREE=$(free | egrep "Mem:" | awk '{print int(10*$7/1024/1024)/10}')
#SWAP_FREE=$(free | egrep "Swap:" | awk '{print int(10*($4/1024))/10 "Mb"}')
MEM_FREE=$(free | egrep "Mem:" | awk '{print 100*($3/$2)}')

echo ${MEM_FREE} 