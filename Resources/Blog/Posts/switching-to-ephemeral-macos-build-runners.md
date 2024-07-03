We recently transitioned our Mac build machines that power our compatibility and documentation build system from a manually configured and maintained collection of Mac mini machines to a new [Orka cluster from MacStadium](https://www.macstadium.com/orka).

### The old bare metal system

Our previous build system grew from a single MacStadium-hosted Intel Mac mini in mid-2020 to four Apple silicon M1 and M2 Mac minis with 16GB RAM each that were in production until we switched to the new Orka cluster.

We use GitLab’s CI system to schedule and keep track of individual jobs for our build system, so each build machine in our old system listened for new work using [GitLab runner](https://docs.gitlab.com/runner/). When each build job starts, the build machine checks out package source code, runs a clean build, runs a DocC documentation build (if the package author opts in), uploads the build log and package documentation to AWS S3, and then reports the build results via an API on Swift Package Index. We ran four concurrent jobs per Mac mini for a total concurrency of 16 builds.

This approach to running a build system worked remarkably well, but it had downsides. Most significantly, there is no isolation between builds. We had four builds of different packages running concurrently on each machine, and even though the Swift compiler is sandboxed when running on macOS, that’s not an ideal situation for security or consistency. The build machines also ran tens or even hundreds of thousands of builds between reboots. We never hit unresolvable issues related to this, but it was always a worry.

The other major downside of this system was needing to keep multiple installs of macOS on different machines. We need to have four different versions of Xcode available to build for the four different versions of Swift that you see in our compatibility matrix, and sometimes that means needing three different versions of macOS depending on Xcode system requirements. This leads to some build machines being overloaded and some build machines being underutilised.

### The new MacStadium Orka system

Our new Orka-based system uses quite a different approach by using ephemeral virtual machines (VMs) to perform completely isolated builds. This means that for each build of each package, we now spawn a fresh macOS virtual machine and SSH into it before executing the same steps as mentioned above. Once the build completes, the virtual machine is destroyed and its state is rolled back so the next build gets an entirely fresh environment.

If you had asked me whether this would be practical before we tried Orka, I’d have guessed that the overhead of spinning up hundreds of thousands of VMs per week would be prohibitive, so we were delighted when we first chatted with MacStadium about Orka to be told virtual machines start in a few seconds. We were even more delighted when “a few” seconds turned out to be less than three:

<picture>
  <source srcset="/images/blog/orka-time-to-launch-vm~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/blog/orka-time-to-launch-vm~light.png" alt="Screenshot of a Terminal command showing a virtual machine launching in ~2.8 seconds.">
</picture>

There are so many advantages to this system in addition to the security and consistency advantages we get from complete isolation, though. We also get to use the cluster at its full efficiency. Each Orka host can launch any of the VM images we have prepared, using any base operating system with any version of Xcode installed, meaning no more uneven usage across the machines we have. We also get yet more security from the entire cluster being behind a firewall.

MacStadium does provide a GitLab runner (and other runners for other services) that works with Orka, but we ended up writing a little custom software for our situation. That’s probably not a huge surprise, since we’re running a very unique kind of build system here! We don’t think anyone else is doing quite what we’re doing! That software isn’t tremendously complex, though, and takes care of starting VMs, executing the build commands over SSH, and deleting them once done.

Finally, it also gives us possibilities for the future. Until now, we simply couldn’t support packages that needed any kind of operating system dependency to be installed. With fresh VMs per build, that’s now something we could start to build.

We couldn’t wrap this up without also telling you all the hardware that we now run on, since it’s quite impressive. We’re running 8x Mac Studio M1 Ultra machines with 128GB of RAM each. That means our total cluster size is 160 M1 cores with a total of 1TB of RAM!

We couldn’t be more pleased with this huge upgrade to our build capability. We also want to thank MacStadium so much for coming up with a way to make this work for an open-source project like this. The team there has been a pleasure to work with for many years, and every request we make has been met with a “let’s find a way” attitude.

### Live in production

All of the compatibility builds that the Swift Package Index processes are now being performed on this cluster, and it’s working incredibly well. We have also run more than 250,000 builds for our [Ready for Swift 6](https://swiftpackageindex.com/ready-for-swift-6) project through the cluster, too, so it has been working hard!

We only have one wish for our new Mac cluster and it would be for Apple to lift the limit on how many virtual machines can run on one host. It’s limited in software to a maximum of two VMs per host, and moving that to four or eight would allow us to use this hardware so much more efficiently. When our cluster is fully allocated at 100% virtual machine capacity, the effective CPU load across the cluster is ~30%. This is because the average Swift build process has quite a bit of downtime around the compilation process while it checks out git repositories or uploads documentation sets to AWS S3. Increasing the number of concurrent builds per host would allow us to use the hardware we have much more efficiently.

Hopefully, you enjoyed reading a little about how our build system works and now have a little more insight into what happens behind the scenes to create that matrix of compatibility you see on package pages. If you have any questions about this, we’d love to answer them on our [Discord server](https://discord.gg/vQRb6KkYRw), so feel free to [drop by and chat](https://discord.gg/vQRb6KkYRw).

**Note:** For full disclosure, MacStadium has supported the Swift Package Index from the beginning. Initially by allowing our use of some hosted Mac mini machines and now by significantly discounting our Orka subscription.
