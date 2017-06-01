# Explainer: Signature-based Resource Loading Restrictions

## The Problem

Developers wish to have fine-grained control over the resources loaded into their pages in order
to mitigate the risk that malicious resources will be loaded. They have a few options to do so at
the moment:

*   [Content Security Policy][CSP] provides URL-based confinement via [host-source][] expressions,
    allowing developers to restrict themselves to known-good sources. For example, the policy
    "`script-src https://example.com/script/trusted.js`" ensures that script executes only when it's
    loaded from the specified URL.

*   [Subresource Integrity][SRI] allows developers to ensure that a script will execute only
    if it contains known-good content. For example, the user agent ensures that script loaded via
    "`<script src='whatever.js' integrity='sha256-...'>`" will only execute when a SHA256 hash of
    the script's content matches the specified integrity attribute.

*   Content Security Policy can layer on top of Subresource Integrity to ensure that [integrity
    checks are required][require-sri-for] for script execution, and [specifying a list of acceptable
    hashes][external]. For example, the policy "`script-src 'sha256-abc' 'sha256-zyx';
    require-sri-for script`" would ensure that script executes only when it matches one of the
    specified hashes, regardless of the server that delivered it.
 
These existing mechanisms are effective, but they also turn out to be somewhat onerous for both
development and deployment. Policies that restrict sources of content need to be quite granular in
order to meaningfully mitigate attacks, which makes robust policies difficult to deploy at scale
(see "[CSP Is Dead, Long Live CSP! On the Insecurity of Whitelists and the Future of Content
Security Policy][csp-is-dead] for more on this point). Hash-based solutions, on the other hand,
require pages and the resources they depend on to update in sequence, which again makes deployment
difficult.

## The proposal

We've discussed [mixing signatures into SRI][gh-449] on and off for quite some time (and folks have
been discussing bringing them into HTTP in general for much longer). They make a different kind of
guarantee than hashes do (provenance of a resource as opposed to its content), but address some of
the original use cases for SRI while being significantly less brittle in the face of updates
(depending on the use case, of course, this flexibility might be a bug or a feature :) ).
 
A simple approach to layering signatures into the platform would be to extend Subresource Integrity
to support validating a resource's signature, as opposed to its content. That is, a developer might
specify one or more [Ed25519 public keys][Ed25519] in an integrity attribute:
 
```html
<script src="https://my.cdn.com/whatever.js" integrity="ed25519-[base64-encoded public key]">
```
 
The developer can sign `whatever.js` when they deploy it, and teach their servers to transmit a
signature along with the resource in any number of ways<sup><a name="ref1"></a>[1](#foot1)</sup>.
For simplicity's sake, let's say that the signature is delivered in a response header which the
user agent could verify before executing the script. This might look like:

```http
HTTP/1.1 200 OK
Accept-Ranges: none
Vary: Accept-Encoding
Content-Type: text/javascript; charset=UTF-8
Access-Control-Allow-Origin: *
...
Integrity: ed25519-[base64-encoded result of Ed25519(`console.log("Hello, world!");`)]
 
console.log("Hello, world!");
```

This mechanism has some interesting properties:
 
*   It addresses many of the "evil CDN" concerns that drove interest in hash-based SRI. If a
    developer's CDN is compromised, an attacker may be able to maliciously alter source files, but
    hopefully won't be able to generate a valid signature for the injected code. Developers will be
    able to ensure that _their_ code is executing, even when it's delivered from a server outside
    their control.

*   Signatures seem simpler to deploy than a complete list of valid content hashes for a site,
    especially for teams who rely on shared libraries controlled by their colleagues. Coordinating
    on a keypair allows rapid deployment without rebuilding the world and distributing new hashes
    to all a libraries' dependencies.

*   Signatures can be layered on top of URL- or nonce-based restrictions in order to further
    mitigate the risk that unintended code is executed on a page. That is, if we provide an
    out-of-band signature requirement mechanism, developers could require that a given resource is
    both specified in an element with a valid nonce attribute, and is signed with a given key. For
    example, via two CSPs: "`script-src 'nonce-abc', script-src 'ed25519-zyx'`". Or even three, if
    you want URL-based confinement as well: "`script-src https://example.com/, script-src
    'nonce-abc', script-src 'ed25519-zyx'`".
 
## FAQs.

*   **Does anyone need this? Really?**

    There's been interest in extending SRI to include signatures since its introduction.
    <https://github.com/w3c/webappsec/issues/449> captures some of the discussion, and though that
    discussion ends up going in a different direction than this proposal, it lays out some of the
    same deployment concerns with hashes that are discussed in this document (and that Google is
    coming across in internal discussions about particular, high-value internal applications).

    It seems likely that many companies are responsible for high-value applications that would
    benefit from robust protections against injection attacks, but who would also desire a less
    brittle deployment mechanism than hashes.

*   **This mechanism just validates a signature against a given public key. Wouldn't this allow an
    attacker to perform version rollback, delivering older versions of a script known to be
    vulnerable to attack?**

    Yes, it would. That's a significant step back from hashes, but a significant step forward from
    URLs.

    It would be possible to mitigate this risk by increasing the scope of the signature and the
    page's assertion to include some of the resource's metadata. For instance, you could imagine
    signing both the resource's body and it's `Date` header, and requiring resources newer than a
    given timestamp.

*   **Key management is hard. Periodic key pinning suicides show that HPKP is a risky thing to
    deploy; doesn't this just replicate that problem in a different way?**

    The key difference between HPKP and the mechanism proposed here is that HPKP has origin-wide
    effect, and is irrevocable (as it kills a connection before the server is able to assert a new
    key). This mechanism, on the other hand, is resource-specific. If a developer loses their key,
    they can generate a new key pair, use the new private key to generate new signature for their
    resources, and deliver the new public key along with the next response. Suicide seems unlikely
    because there's no built-in persistence.

    It is, of course, possible that we'd introduce a persistent delivery mechanism from which it
    would be more difficult to recover. [Origin Policy][origin-policy] seems like a good candidate
    for that kind of footgun. We'll need to be careful as we approach the design if and when we
    decide that's an approach we'd like to take.

*   **Wouldn't it be better to reuse some concepts from web PKI? X.509? Chaining to roots? Etc?**

    Certs are an incredibly complicated ecosystem. This proposal is very small and simple. That also
    means that it's easy to reason about, easy to explain its benefits, and easy to recognize its
    failings. It paves the way for something more complicated in the future if it turns out that
    complexity is warranted.

-------

1.  <a name="foot1"></a> For example: the signature could be inline in the resource's body via
    an encoding like [Web Packaging proposes][web-packaging]. Or, the signature could be part of a
    manifest that contains lots of signatures for an origin. Or it could be a resource [specified by
    a Link header][link-header]. Or part of the server's TLS certificate! Or an etag! Etc!
    [↩︎](#ref1)

[CSP]: https://w3c.github.io/webappsec-csp/
[host-source]: https://w3c.github.io/webappsec-csp/#grammardef-host-source
[SRI]: https://w3c.github.io/webappsec-subresource-integrity/
[require-sri-for]: https://w3c.github.io/webappsec-subresource-integrity/#require-sri-for
[external]: https://w3c.github.io/webappsec-csp/#external-hash
[csp-is-dead]: https://research.google.com/pubs/pub45542.html
[gh-449]: https://github.com/w3c/webappsec/issues/449
[Ed25519]: https://ed25519.cr.yp.to/
[origin-policy]: https://wicg.github.io/origin-policy/
[web-packaging]: https://github.com/dimich-g/webpackage/
[link-header]: https://tools.ietf.org/html/rfc6249#section-5.1
