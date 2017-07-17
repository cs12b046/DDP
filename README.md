Single GPU
===========
For computing SCCs in Single GPU:
	i) GO to single_gpu directory
	ii) nvcc -o scc coloring_scc.cu
	iii) ./scc graph_file_name_in_edge_list 0


For computing in multiple GPUs
	i) Go to multi_gpu directory and open forward_backward_mgpu.cu file and change #define NGPUS
	ii) nvcc -o scc forward_backward_mgpu.cu
	iii) ./scc graph_sorted_edge_list_file 
