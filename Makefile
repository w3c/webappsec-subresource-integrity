all: clean index.html index.bikeshed.html

clean:
	rm -rf index.html

index.html: spec.markdown template.erb
	sed -e 's/\[\[/\\[\\[/g' -e 's/\]\]/\\]\\]/g' ./spec.markdown | kramdown --parse-block-html --template='template.erb' > index.html

index.bikeshed.html: index.bikeshed.bs
	bikeshed -f spec ./index.bikeshed.bs

publish: all
	git push origin master
	git push origin master:gh-pages
