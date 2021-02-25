.PHONY: plan apply clean clobber

plan: .terraform/tfplan.zip

apply: .terraform/tfplan.zip
	terraform apply $<

clean:
	rm -rf .terraform/tfplan.zip

clobber:
	rm -rf .terraform*

.terraform:
	terraform init

.terraform/tfplan.zip: *.tf | .terraform
	terraform plan -out $@
