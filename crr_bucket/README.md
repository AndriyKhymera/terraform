*Two-way CRR with terraform*

Query state(data) if bucket exist region 2
Create bucket with region 1, if there is not bucket in region 2,
	if there is bucket -- enable CRR
Setup iam role to have access

Query state(data) if bucket exist region 1
Create bucket with disable CRR region 2, if there is not bucket in region 1,
	if there is bucket -- enable CRR
Setup iam role to have access