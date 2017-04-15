#include <iostream>
#include <algorithm>
using namespace std;

class Edge{
	public:
		int src,dest;
};

bool comp(const Edge& lhs, const Edge& rhs)
{
    if(lhs.src == rhs.src)
        return (lhs.dest < rhs.dest);
    else
        return lhs.src < rhs.src;
}

int main(){
	int v,e;
	cin>>v>>e;
	Edge* edgeList = new Edge[e];
	for(int i=0;i<e;i++)
		cin>>edgeList[i].src>>edgeList[i].dest;
	sort(edgeList,edgeList + e, comp);
	cout<<v<<" "<<e<<endl;
	for(int i=0;i<e;i++)
		cout<<edgeList[i].src<<" "<<edgeList[i].dest<<endl;
}
