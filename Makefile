.SILENT:
.PHONY: app-version

help:
	{ grep --extended-regexp '^[a-zA-Z_-]+:.*#[[:space:]].*$$' $(MAKEFILE_LIST) || true; } \
	| awk 'BEGIN { FS = ":.*#[[:space:]]*" } { printf "\033[1;32m%-22s\033[0m%s\n", $$1, $$2 }'

env-create: # 1) create .env file
	./make.sh env-create

terraform-init: # 2) terraform init (updgrade) + validate
	./make.sh terraform-init

terraform-create: # 2) terraform valiate + apply
	./make.sh terraform-create

# kind-create: # start kind + setup argocd + image-updater
# 	./make.sh kind-create

argocd-open: # 3) open argocd (website)
	./make.sh argocd-open

argocd-login: # 3) argocd login (terminal)
	./make.sh argocd-login

argocd-finalize-ns: # 3) argocd-finalize-ns
	./make.sh argocd-finalize-ns

image-updater-logs: # 5) argocd image updater logs
	./make.sh image-updater-logs

terraform-destroy: # 8) terraform destroy
	./make.sh terraform-destroy
