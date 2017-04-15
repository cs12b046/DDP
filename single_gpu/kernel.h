class GraphCSR{
  public:
    int v;
    int e;
    int* vlist;
    int* elist;
};
//__device__ int* old;
/* Defination of all the kernel is here */
//__global__ void kernel_init_old(int* old, int* d_graph);
__global__ void kernel_trim(int* d_v, int* d_vlist, int* d_elist, int* d_graph, int* d_allowed_v, int* d_terminate_trim, int* d_leftout);
__global__ void kernel_Init_Color(int* d_v, int* d_graph, int* d_allowed_v);
__global__ void kernel_Init_Color_Prev(int* d_v, int* d_graph, int* d_allowed_v);
__global__ void kernel_Init(int* d_v, int* d_graph, int* d_allowed_v);
__global__ void kernel_Init_SCC(int* d_v, int* d_graph);
__global__ void kernel_Init_Allowed_Vert(int* d_allowed_v, int* d_graph);
__global__ void terminate(int* d_v_prev, int* d_v_new, int* d_terminate, int* graph, int* d_allowed_v);
__global__ void kernel_COLORING(int* d_graph, int* d_vlist, int* d_elist, int* d_v, int* d_allowed_v, int* d_terminate_color, int* old);
//__global__ void kernel_COLORING_OPT(GraphCSR* d_g, int* d_v, int* d_allowed_v);
//__global__ void kernel_BWD(int* graph, int* d_e1, int* d_e2, int* d_allowed_v, int* d_vertices, int* d_v);
__global__ void kernel_BWD(int* graph, int* d_vlist, int* d_elist, int* d_allowed_v, int* d_vertices, int* d_v, int* d_terminate_BWD);
__global__ void kernel_vertex_with_org_color(int* d_v, int* d_allowed_v, int* graph, int* d_out, int* old);
__global__ void kernel_change_allowed(int* d_allowed_v, int* d_out_colors, int* graph, int* d_leftout);
__global__ void kernel_SCC(int* d_v,int d_i,int *d_algo_out, int* d_graph, int* d_count);
__global__ void kernel_Total_SCC(int* d_graph,int *d_v, int* d_total_scc);
