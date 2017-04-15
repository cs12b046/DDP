/*
 * Author : Pankaj Yadav
 * Date : 21 Jan 2016
 * Work : This file describe GPU is using to extract SCC
 * Class : Gpu
 */

#include "edge.h"
class Gpu{
public:
    int from;   // From this index
    int to;     // To this index
    Graph graph;    //input graph after partition
    GraphCSR graphCSR;  // Graph after converting into CSR
    int* vertex_covered_for_fb; // vertex covered by forward or backward
    bool isVertexPresent(int vertex_id); //This will return is this vertex_id is present in this GPU
    bool isVertexCoveredByFB(int vertex_id); // This function will check is vertex_id already explored
    Map
};
