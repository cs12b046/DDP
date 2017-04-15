#include <iostream>
#include <stdio.h>
#include <unistd.h>
#include <algorithm>
//#include "Edge.h"
bool myComparator(Edge e1, Edge e2){
    if(e1.dest == e2.dest)
        return (e1.src < e2.src);
    return (e1.dest < e2.dest);
}
GraphCSR* convertToCSR(int h_v, int h_e, Edge* edgeList){
    GraphCSR* g;
    g = (GraphCSR *)malloc(sizeof(GraphCSR));
    g->v = h_v;
    g->e = h_e;
    g->vlist = (int *)malloc((h_v+1)*sizeof(int));
    g->elist = (int *)malloc(h_e*sizeof(int));
    g->vlist[0] = 0;
    int index = 0;
    /* Pick up a vertex and try to convert to csr */
    int number_of_edges = 0;
    int offset = 0;
    for(int i=0;i<h_v;i++){
         number_of_edges = 0;
         for(int j=offset;j<h_e;j++){
             if(edgeList[j].src == i){
                 g->elist[index] = edgeList[j].dest;
                 offset++;
                 index++;
                 number_of_edges++;
             }
             else
                break;
         }
         g->vlist[i+1] = g->vlist[i] + number_of_edges;
    }
    return g;
}

GraphCSR* convertToCSRPrime(int h_v, int h_e, Edge* edgeList){
    GraphCSR* g;
    g = (GraphCSR *)malloc(sizeof(GraphCSR));
    g->v = h_v;
    g->e = h_e;
    std::cout<<"/* Sorting started */"<<std::endl;
    std::sort(edgeList,edgeList+h_e,myComparator);
    std::cout<<"/* Sorting done */"<<std::endl;
    /*for(int i=0;i<h_e;i++){
        h_e1[i] = edgeList[i].src;
        h_e2[i] = edgeList[i].dest;
        std::cout<<edgeList[i].src<<edgeList[i].dest<<std::endl;
    }*/
    g->vlist = (int *)malloc((h_v+1)*sizeof(int));
    g->elist = (int *)malloc(h_e*sizeof(int));
    g->vlist[0] = 0;
    int index = 0;
    int offset = 0;
    /* Pick up a vertex and try to convert to csr */
    int number_of_edges = 0;
    for(int i=0;i<h_v;i++){
         number_of_edges = 0;
         for(int j=offset;j<h_e;j++){
             if(edgeList[j].dest == i){
                 g->elist[index] = edgeList[j].src;
                 index++;
                 offset++;
                 number_of_edges++;
             }
             else
                break;
         }
         g->vlist[i+1] = g->vlist[i] + number_of_edges;
    }
    return g;
}
