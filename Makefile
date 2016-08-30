all: clean index.html index.kramdown.html

clean:
	rm -rf index.html index.kramdown.html

index.kramdown.html: spec_v1.markdown template.erb
	sed -e 's/\[\[/\\[\\[/g' -e 's/\]\]/\\]\\]/g' ./spec_v1.markdown | kramdown --parse-block-html --template='template.erb' > index.kramdown.html

index.html: index.bs
	curl https://api.csswg.org/bikeshed/ -F file=@index.bs -F force=1 --fail -o index.html

local:
	bikeshed -f spec index.bs

publish: all
	git push origin master
	git push origin master:gh-pages
