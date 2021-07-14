plan: .terraform/tfplan.zip

apply: .terraform/tfplan.zip
	terraform apply $<

clean:
	rm -rf .terraform/tfplan.zip

clobber:
	rm -rf .terraform*

logs:
	aws logs tail $$(terraform output -raw pypi_api_log_group) --follow

.PHONY: plan apply clean clobber logs

.terraform/tfplan.zip: *.tf | .terraform
	terraform plan -out $@

.terraform:
	terraform init
