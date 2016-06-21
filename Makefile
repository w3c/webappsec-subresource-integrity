all: clean index.html index.bikeshed.html

clean:
	rm -rf index.html index.bikeshed.html

index.html: spec.markdown template.erb
	sed -e 's/\[\[/\\[\\[/g' -e 's/\]\]/\\]\\]/g' ./spec.markdown | kramdown --parse-block-html --template='template.erb' > index.html

index.bikeshed.html: index.bikeshed.bs
	curl https://api.csswg.org/bikeshed/ -F file=@index.bikeshed.bs -F force=1 > ./index.bikeshed.html

publish: all
	git push origin master
	git push origin master:gh-pages
