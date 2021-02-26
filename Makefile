plan: .terraform/tfplan.zip

apply: .terraform/tfplan.zip
	terraform apply $<

clean:
	rm -rf .terraform/tfplan.zip

clobber:
	rm -rf .terraform*

.PHONY: plan apply clean clobber

.terraform/tfplan.zip: *.tf | .terraform
	terraform plan -out $@

.terraform:
	terraform init
