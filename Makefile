gen: clean gen-clusters prettify-files git

clean:
	rm -rf infra/terraform/generated

gen-clusters:
	hack/generate-clusters.sh infra/clusters

prettify-files:
	hack/prettify-generated-json.sh infra/terraform/generated

git:
	git add infra/terraform/generated/*
