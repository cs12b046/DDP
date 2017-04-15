#include <iostream>
#include <stdio.h>
#include <string>
#include <unistd.h>
#include <time.h>
#include "Edge.h"
#include "kernel.c"
#include "convert.c"

int main(int argc, char const *argv[]) {
    //int* h_e1;
    //int* h_e2;
    //int* d_e1;
    //int* d_e2;
    int v,e;
    int* h_terminate_color;
    int* d_terminate_color;
    int* h_graph;
    int* d_graph;
    int* h_allowed_v;
    int* d_allowed_v;
    int* h_v;
    int* d_v;
    int* d_v_prev;
    int* h_out_colors;
    int* d_out_colors;
    int* d_terminate_BWD;
    int* h_terminate_BWD;
    int* d_terminate_trim;
    int* h_terminate_trim;
    int* d_prev_BWD;
    int* h_leftout;
    int* d_leftout;
    int* h_algo_out;
    int* d_algo_out;
    int* d_count;
    int* h_count;
    int* old;
    int number_of_iteration = 0;

    /* Code for take input graph */
    if(argc < 3){
        std::cout<<"Error : Invalid Arguents\n";
        return 0;
    }
    FILE* fp;
    fp = fopen(argv[1],"r");
    fscanf(fp,"%d %d",&v, &e);
    cudaMalloc((void **)&old,v*sizeof(int));

    /* Allocates memory for edges at host and at device*/
    //h_e1 = (int *)malloc(e*sizeof(int));
    //h_e2 = (int *)malloc(e*sizeof(int));
    //cudaMalloc((void **)&d_e1,e*sizeof(int));
    //cudaMalloc((void **)&d_e2,e*sizeof(int));

    /* Taking input from file */
    Edge* edgeList;
    edgeList = (Edge *)malloc(e*sizeof(Edge));
    for(int i=0;i<e;i++){
        Edge temp_edge;
        fscanf(fp,"%d %d",&temp_edge.src,&temp_edge.dest);
	edgeList[i] = temp_edge;
    }
    std::cout << "/* Reading done */" << std::endl;
    /* Convert Graph in CSR */
    GraphCSR* h_g = convertToCSR(v,e,edgeList);
    int* d_vlist;
    int* d_elist;
    cudaMalloc((void **)&d_vlist, (v+1)*sizeof(int));
    cudaMemcpy(d_vlist,h_g->vlist,(v+1)*sizeof(int),cudaMemcpyHostToDevice);
    cudaMalloc((void **)&d_elist, (e)*sizeof(int));
    cudaMemcpy(d_elist,h_g->elist,(e)*sizeof(int),cudaMemcpyHostToDevice);
    std::cout << "/* Converted into CSR */" << std::endl;
    /* Convert graph_prime */
    GraphCSR* h_g_prime = convertToCSRPrime(v,e, edgeList);
    int* d_vlist_prime;
    int* d_elist_prime;
    cudaMalloc((void **)&d_vlist_prime, (v+1)*sizeof(int));
    cudaMemcpy(d_vlist_prime,h_g_prime->vlist,(v+1)*sizeof(int),cudaMemcpyHostToDevice);
    cudaMalloc((void **)&d_elist_prime, (e)*sizeof(int));
    cudaMemcpy(d_elist_prime,h_g_prime->elist,(e)*sizeof(int),cudaMemcpyHostToDevice);
    std::cout << "/* Converted into CSR (G_Prime) */" << std::endl;
    //cudaMemcpy(graph,d_g,sizeof(GraphCSR),cudaMemcpyDeviceToHost);
    /* This is not the part of program this is part of debugging please remove it after debugging */
    // std::cout<<"Graph in CSR format"<<std::endl;
    // // GraphCSR g = convertToCSR(v,e,h_e1,h_e2);
    // for(int i=0;i<v+1;i++){
    //     std::cout<<graph->vlist[i]<<" ";
    // }
    // std::cout<<std::endl;
    // for(int i = 0;i<e;i++){
    //     std::cout<<graph->elist[i]<<" ";
    // }
    // std::cout<<std::endl;
    // std::cout<<"Graph ends Here"<<std::endl;
    /* Till here */

    /* Copying edge List to device */
    //cudaMemcpy(d_e1,h_e1,e*sizeof(int),cudaMemcpyHostToDevice);
    //cudaMemcpy(d_e2,h_e2,e*sizeof(int),cudaMemcpyHostToDevice);

    /* Setup for algorithm */
    h_terminate_color = (int*) malloc(sizeof(int));
    h_allowed_v = (int*) malloc(v*sizeof(int));
    h_graph = (int* )malloc(2*sizeof(int));
    h_v = (int* )malloc(v*sizeof(int));
    h_out_colors = (int* )malloc(v*sizeof(int));
    h_terminate_BWD = (int *)malloc(sizeof(int));
    h_terminate_trim = (int *)malloc(sizeof(int));
    h_leftout = (int*) malloc(sizeof(int));
    h_algo_out = (int* )malloc(v*sizeof(int));
    h_count = (int*) malloc(sizeof(int));

    cudaMalloc((void **)&d_v,v*sizeof(int));
    cudaMalloc((void **)&d_graph,2*sizeof(int));
    cudaMalloc((void **)&d_allowed_v,v*sizeof(int));
    cudaMalloc((void **)&d_terminate_color,sizeof(int));
    cudaMalloc((void **)&d_terminate_trim,sizeof(int));
    cudaMalloc((void **)&d_terminate_BWD,sizeof(int));
    cudaMalloc((void **)&d_v_prev,v*sizeof(int));
    cudaMalloc((void **)&d_out_colors,v*sizeof(int));
    cudaMalloc((void **)&d_prev_BWD,v*sizeof(int));
    cudaMalloc((void **)&d_leftout,sizeof(int));
    cudaMalloc((void **)&d_algo_out,v*sizeof(int));
    cudaMalloc((void **)&d_count,sizeof(int));

    h_graph[0] = v;
    h_graph[1] = e;
    /* Start timer here */
    clock_t tStart = clock();
    cudaMemcpy(d_graph,h_graph,2*sizeof(int), cudaMemcpyHostToDevice);

    /*  Finding numbers of blocks for vertex parallelism */
    int number_of_blocks = ceil((v*1.0)/512.0);
    int number_of_thread_per_block = ceil(v/number_of_blocks)+1;
    int number_of_blocks_e = ceil((e*1.0)/512.0);
    int number_of_thread_per_block_e = ceil(e/number_of_blocks)+1;

    /* Init d_allowed_v and h_allowed_v */
    kernel_Init_Allowed_Vert<<<number_of_blocks,number_of_thread_per_block>>>(d_allowed_v,d_graph);
    cudaMemcpy(h_allowed_v,d_allowed_v,v*sizeof(int),cudaMemcpyDeviceToHost);

    h_leftout[0] = v;
    cudaMemcpy(d_leftout,h_leftout,sizeof(int),cudaMemcpyHostToDevice);

    // /* Just for debugging */
    // kernel_COLORING<<<number_of_blocks,number_of_thread_per_block>>>(d_graph,d_vlist,d_elist,d_v,d_allowed_v);
    // cudaMemcpy(h_v,d_v,v*sizeof(int),cudaMemcpyDeviceToHost);
    // for(int i=0;i<v;i++){
    //         std::cout<<h_v[i]<< " ";
    // }
    // std::cout<<std::endl;
    // return 0;
    // /* Till here */
    /* Init old values*/
    //cudaMemset(old,-1,v*sizeof(int));
   // int* h_old = (int *)malloc(v*sizeof(int));
    //cudaMemcpy(h_old,old,v*sizeof(int),cudaMemcpyDeviceToHost);
    //std::cout<<"old[0] "<<old[0]<<std::endl;
    //sleep(1);
    //boost::this_thread::sleep( boost::posix_time::seconds(1) );
    //kernel_init_old<<<1,1>>>(d_graph);
    while(h_leftout[0] > 0){
        //sleep(3);
	number_of_iteration++;
        kernel_Init_Color<<<number_of_blocks,number_of_thread_per_block>>>(d_v,d_graph,d_allowed_v);
        /* code for trimming */
        h_terminate_trim[0] = 0;
        while(h_terminate_trim[0] == 0){
            h_terminate_trim[0] = 1;
            cudaMemcpy(d_terminate_trim,h_terminate_trim,sizeof(int),cudaMemcpyHostToDevice);
            kernel_trim<<<number_of_blocks,number_of_thread_per_block>>>(d_v,d_vlist,d_elist,d_graph,d_allowed_v,d_terminate_trim, d_leftout);
            kernel_trim<<<number_of_blocks,number_of_thread_per_block>>>(d_v,d_vlist_prime,d_elist_prime,d_graph,d_allowed_v,d_terminate_trim, d_leftout);
            cudaMemcpy(h_terminate_trim,d_terminate_trim,sizeof(int),cudaMemcpyDeviceToHost);
        }
	/*std::cout<<"TRIM END"<<std::endl;*/
        //std::cout << "/* END OF TRIM */" << std::endl;
        //kernel_Init_Color_Prev<<<number_of_blocks,number_of_thread_per_block>>>(d_v_prev,d_graph,d_allowed_v);
        /* Propogating Colors */
        h_terminate_color[0] = 0;
        while(h_terminate_color[0] == 0){
            h_terminate_color[0] = 1;
            cudaMemcpy(d_terminate_color,h_terminate_color,sizeof(int),cudaMemcpyHostToDevice);
            //kernel_COLORING<<<number_of_blocks,number_of_thread_per_block>>>(d_e1,d_e2,d_v,d_allowed_v,d_graph);
            kernel_COLORING<<<number_of_blocks,number_of_thread_per_block>>>(d_graph,d_vlist,d_elist,d_v,d_allowed_v,d_terminate_color,old);
            //terminate<<<number_of_blocks,number_of_thread_per_block>>>(d_v_prev,d_v, d_terminate_color,d_graph,d_allowed_v);
            //cudaMemcpy(d_v_prev,d_v,v*sizeof(int),cudaMemcpyDeviceToDevice);
            cudaMemcpy(h_terminate_color,d_terminate_color,sizeof(int),cudaMemcpyDeviceToHost);
            // if(atoi(argv[2]) > 0)
            //cudaMemcpy(h_v,d_v,v*sizeof(int),cudaMemcpyDeviceToHost);
        }
        // std::cout << "/* At iteration " <<number_of_iteration<<" */"<< std::endl;
        // for(int iter=0;iter<v;iter++){
        //     std::cout <<iter<<"-->"<<h_v[iter]<<std::endl;
        // }
        //std::cout << "/* END OF COLOR Propogating */" << std::endl;
        /* Find vertex with the original colors */
        kernel_vertex_with_org_color<<<number_of_blocks,number_of_thread_per_block>>>(d_v,d_allowed_v,d_graph,d_out_colors);
        cudaMemcpy(h_out_colors,d_out_colors,v*sizeof(int),cudaMemcpyDeviceToHost);

        // for(int i=0;i<v;i++){
        //         std::cout<<h_out_colors[i]<< " ";
        // }
        // std::cout<<std::endl;

        /* this kernel for init d_prev_BWD */
        //kernel_Init<<<number_of_blocks,number_of_thread_per_block>>>(d_prev_BWD,d_graph,d_allowed_v);

        /* Code for backward reach */
        h_terminate_BWD[0] = 0;
        while(h_terminate_BWD[0] == 0){
            h_terminate_BWD[0] = 1;
            cudaMemcpy(d_terminate_BWD,h_terminate_BWD,sizeof(int),cudaMemcpyHostToDevice);
            //kernel_BWD<<<number_of_blocks,number_of_thread_per_block>>>(d_graph,d_e2,d_e1,d_allowed_v,d_out_colors, d_v);
            kernel_BWD<<<number_of_blocks,number_of_thread_per_block>>>(d_graph,d_vlist_prime,d_elist_prime,d_allowed_v,d_out_colors,d_v,d_terminate_BWD,old);
            //terminate<<<number_of_blocks,number_of_thread_per_block>>>(d_prev_BWD,d_out_colors,d_terminate_BWD,d_graph,d_allowed_v);
            //cudaMemcpy(h_out_colors,d_out_colors,v*sizeof(int),cudaMemcpyDeviceToHost);
            cudaMemcpy(h_terminate_BWD,d_terminate_BWD,sizeof(int),cudaMemcpyDeviceToHost);
            //cudaMemcpy(d_prev_BWD,d_out_colors,v*sizeof(int),cudaMemcpyDeviceToDevice);
            // for(int i=0;i<v;i++){
            //         std::cout<<h_out_colors[i]<< " ";
            // }
            // std::cout<<std::endl;
        }
        //std::cout << "/* END OF BWD */" << std::endl;
        kernel_change_allowed<<<number_of_blocks,number_of_thread_per_block>>>(d_allowed_v,d_out_colors,d_graph,d_leftout);
        cudaMemcpy(h_leftout,d_leftout,sizeof(int),cudaMemcpyDeviceToHost);
        // cudaMemcpy(h_v,d_v,v*sizeof(int),cudaMemcpyDeviceToHost);
        // for(int i=0;i<v;i++){
        //         std::cout<<h_v[i]<< " ";
        // }
        //std::cout << "/* END OF leftout */ " << h_leftout[0]<< std::endl;
	//std::cout<<h_leftout[0]<<std::endl;
    }

    /* Code for printing final color */
    int choice = atoi(argv[2]);
    if(choice >= 1){
        cudaMemcpy(h_v,d_v,v*sizeof(int),cudaMemcpyDeviceToHost);
        std::cout<<"============COLORS=============="<<std::endl;
        for(int i=0;i<v;i++){
            std::cout<<i<<" --> "<<h_v[i]<<std::endl;
        }
        std::cout<<"=============SCC================"<<std::endl;
        /* Code for extracting SCC from colors*/
        for(int i=0;i<v;i++){
            h_count[0] = 0;
            kernel_Init_SCC<<<number_of_blocks,number_of_thread_per_block>>>(d_algo_out,d_graph);
            cudaMemcpy(d_count,h_count,sizeof(int),cudaMemcpyHostToDevice);
            kernel_SCC<<<number_of_blocks,number_of_thread_per_block>>>(d_v,i,d_algo_out,d_graph,d_count);
            cudaMemcpy(h_algo_out,d_algo_out,v*sizeof(int),cudaMemcpyDeviceToHost);
            cudaMemcpy(h_count,d_count,sizeof(int),cudaMemcpyDeviceToHost);
            for(int j=0;j<v;j++){
                  if(h_algo_out[j] > 0)
                    std::cout<<j<<" ";
            }
            if(h_count[0] > 0)
                std::cout<<std::endl;
        }
        std::cout<<"================================"<<std::endl;
    }
    /* Printing number of cluster and time taken by the progam */
    clock_t tEnd = clock();
    int* d_total_scc;
    int* h_total_scc = (int*)malloc(sizeof(int));
    cudaMalloc((void**)&d_total_scc,sizeof(int));
    h_total_scc[0] = 0;
    cudaMemcpy(d_total_scc,h_total_scc,sizeof(int),cudaMemcpyHostToDevice);
    kernel_Total_SCC<<<number_of_blocks,number_of_thread_per_block>>>(d_graph,d_v, d_total_scc);
    cudaMemcpy(h_total_scc,d_total_scc,sizeof(int),cudaMemcpyDeviceToHost);
    std::cout<<"|V| = "<<v<<" |e| = "<<e<<std::endl;
    std::cout<<"Total SCC are -> "<<h_total_scc[0]<<std::endl;
    printf("Time taken: %.2fs\n", (double)(tEnd - tStart)/CLOCKS_PER_SEC);
    printf("/* Number of iteration %d */\n",number_of_iteration);
    /* Freeing all the space used */
    //free(h_e1);
    //free(h_e2);
    //cudaFree(d_e1);
    //cudaFree(d_e2);
    free(h_terminate_color);
    cudaFree(d_terminate_color);
    free(h_graph);
    cudaFree(d_graph);
    free(h_allowed_v);
    cudaFree(d_allowed_v);
    free(h_v);
    cudaFree(d_v);
    cudaFree(d_v_prev);
    free(h_out_colors);
    cudaFree(d_out_colors);
    cudaFree(d_terminate_BWD);
    free(h_terminate_BWD);
    cudaFree(d_prev_BWD);
    free(h_leftout);
    cudaFree(d_leftout);
    free(h_algo_out);
    cudaFree(d_algo_out);
    cudaFree(d_count);
    free(h_count);

    return 0;
}
