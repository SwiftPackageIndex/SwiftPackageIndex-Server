![The Swift Package Index logo next to the Amazon logo](/images/blog/swift-package-index-and-aws-logos.png)

It may surprise you to learn how much hosting infrastructure a site like the Swift Package Index needs.

We obviously need a web server, or actually a few web servers, as we want redundancy so the site is never down for you, even when we do maintenance. Of course, we also need a redundant database to store all that metadata. We also need a staging site so we can test changes before they go live. There’s no point in having a redundant hosting plan if you push changes into production that completely break the site!

Then there’s our “build system” that powers all the compatibility information. That system consists of 10 very powerful machines that crunch through more than 500,000 Swift builds during a busy month. Those machines also build all the documentation that we host for almost 1,000 packages.

The build machines also generate hundreds of thousands of build logs per month and millions of documentation files that need hundreds of gigabytes of storage. We have been using [Amazon Web Services (AWS)](https://aws.amazon.com/) for this storage so far, but our costs were starting to rise as we hosted more and more documentation.

Which is why we’re delighted to announce today that AWS is [joining our set of infrastructure sponsors](/supporters) by donating credits to the project. We’ll use these credits to continue to host the logs and documentation that you use every day.

We want to say a huge thank you to every one of our infrastructure sponsors for keeping this site hosted and processing. We could not do what we do without their support.

We’d also love to [thank all our supporters](/supporters) who keep this project running as smoothly as it does. Your support is invaluable.
