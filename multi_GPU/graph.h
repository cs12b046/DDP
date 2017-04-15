/*
 * Author : Pankaj Yadav
 * Date : 20 Jan 2016
 * Work : This file describe graph and reads the graph from file
 * Class : Graph
 */

 #include <iostream>
 #include <string>
 #include <stdio.h>
 //#include <thrust/host_vector.h>
 #include <utility>
 //#include <thrust/device_vector.h>
 //#include <thrust/device_ptr.h>
 //#include <thrust/fill.h>
 #include "edge.h"
 //#include "mapping.h"

 //using namespace thrust;
 #ifndef _GRAPH_H_
 #define _GRAPH_H_
 class Graph_d{
	public:
		int v;
		int e;
		Edge* edgeList;
 };

 class Graph{
 public:
     int v;
     int e;
     Edge* edgeList;
     Graph();
     Graph(std::string file_name); // Constructr
     Graph* copy();
     //std::pair<Graph*,Mapping> subGraph(int n, int m);
     int differentVertex();
     void print();
 };

Graph::Graph(){
    this->v = 0;
    this->e = 0;
}

Graph* Graph::copy(){
    Graph* g;
    g = new Graph[1];
    g->v = v;
    g->e = e;
    g->edgeList = new Edge[e];
    for(int i=0;i<e;i++){
        g->edgeList[i].src = edgeList[i].src;
        g->edgeList[i].dest = edgeList[i].dest;
    }
    return g;
}
/*
 * This Constructr will read the graph
 */
Graph::Graph(std::string file_name){
    FILE* fp;
    fp = fopen(file_name.c_str(),"r");
    fscanf(fp,"%d %d",&v,&e);
    edgeList = new Edge[e];
    for(int i=0;i<e;i++){
        Edge temp_edge;
        fscanf(fp,"%d %d",&temp_edge.src,&temp_edge.dest);
        edgeList[i] = (temp_edge);
    }
    fclose(fp);
}
/* Number of distinct vertex in a graph*/
/*int Graph::differentVertex(){
    unordered_set<int> s;
    for (int i = 0 ; i < edgeList.size(); i++){
        s.insert(edgeList[i].src);
        s.insert(edgeList[i].dest);
    }
    return s.size();
}*/
/* Construct a subgraph [n,m] */

/*std::pair<Graph*,Mapping> Graph::subGraph(int n, int m){
    std::pair<Graph*,Mapping> ret_pair;
    Graph* subgraph;
    subgraph = new Graph[1];
    subgraph->e = m-n+1;
    host_vector<Edge> H(edgeList.begin()+n, edgeList.begin()+m+1);
    subgraph->edgeList = H;
    ret_pair.second = Mapping(H);
    subgraph->v = ret_pair.second.trans.size();
    ret_pair.first = subgraph;
    return ret_pair;
}*/

 /* Print the graph*/
 void Graph::print(){
     std::cout<<"====Printing Graph====="<<std::endl;
     std::cout<<v<<" "<<e<<std::endl;
     for(int i=0;i<e;i++){
         std::cout<<edgeList[i].src<<" "<<edgeList[i].dest<<std::endl;
     }
     std::cout<<"======================="<<std::endl;
 }

__global__ void kernel_cuda(Graph_d* d_graph){
	printf("Number of Vertexes %d\n",d_graph->v);
	printf("Number of Edges %d\n", d_graph->e);
	printf("%d %d\n",d_graph->edgeList[0].src,d_graph->edgeList[0].dest);
}
Graph_d* copyGraphToGPU(Graph* h_graph){
	Graph_d* d_graph;
	/* Space for a graph has been allocated to device */
	cudaMalloc((void **)&d_graph, sizeof(Graph_d));
	//device_vector<Edge> d_edgeList = h_graph->edgeList;
	cudaMemcpy(&(d_graph->v),&(h_graph->v), sizeof(int),cudaMemcpyHostToDevice);
	cudaMemcpy(&(d_graph->e), &(h_graph->e),sizeof(int), cudaMemcpyHostToDevice);
	Edge* edge_pointer;
	cudaMalloc((void **)&edge_pointer,h_graph->e*sizeof(Edge));
	cudaMemcpy(&(d_graph->edgeList),&(edge_pointer),sizeof(Edge *),cudaMemcpyHostToDevice);
	for(int i=0;i<h_graph->e;i++){
		cudaMemcpy(&(edge_pointer[i].src), &(h_graph->edgeList[i].src), sizeof(int), cudaMemcpyHostToDevice);
		cudaMemcpy(&(edge_pointer[i].dest), &(h_graph->edgeList[i].dest), sizeof(int), cudaMemcpyHostToDevice);
	}
	// std::cout<<"Kya hua ye\n";
	// kernel_cuda<<<1,1>>>(d_graph);
	// cudaDeviceSynchronize();
	return d_graph;
}

#endif
