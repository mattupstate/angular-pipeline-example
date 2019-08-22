# Angular CI+CD Pipeline Example

This repository is the artifact of my experience as I taught myself how to setup an Angular project, provide additional tooling to contributors to run the CI pipeline with minimal differences between the local development environment and the CI server (Semaphore), and continuously deliver the application to the public using a combination of an artifact repository (S3) and a CDN service (Fastly).

As part of this effort I hope to use a (subjectively) minimal amount of tools that are (subjectively) popular and (subjectively) easy to install such that it can (arguably) be replicated in most modern software development organizations.

## CI+CD Pipeline

The CI+CD pipeline can be expressed as a set of ordered steps:

1. Unit tests
2. Static analysis
3. Dependency audit
4. End-to-end tests
5. Infrastructure change test
6. Publish release candidate
7. Smoke tests
8. Apply infrastructure changes

These steps would execute on every change to the `master` branch. Where as any other branch the last step would be `#5`. Implicit in this pipeline are additional steps that build the execution contexts and distributable application artifacts.

I've implemented this pipeline using a `Makefile`. I've chosen `make` as a tool for it's relative ubiquity, stability and simplicity. Each of the following `make` commands map to the logical pipeline steps described above:

1. `make test`
2. `make analysis`
3. `make audit`
4. `make e2e`
5. `make release-plan`
6. `make release-candidate`
7. `make smoke-test`
8. `make release`

## Execution Contexts

Docker and Docker Compose are used to manage two primary execution contexts that support the pipeline. I've chosen these tools for their relative ubiquity and popularity. Additionally, these tools affords one to express an execution context in the form of configuration files that are stored in source control and can be (mostly) deterministically built under the assumption that internet infrastructure that delivers dependencies is reliably maintained and secure. The following is a description of each context.

### Test Context

The test execution context is defined in the second stage of the [multi-stage](https://docs.docker.com/develop/develop-images/multistage-build/) `Dockerfile`. It is automatically built prior to executing `make test` `make analysis` or `make audit`. Optionally, `make test-image` is available should one want to build the test context in isolation.

This resulting image contains all the dependencies required to run unit tests, perform static analysis, audit dependency vulnerabilities, and build the final Angular application artifacts. Pipeline steps that rely on this context will be executed in containers created from this image.

### End-to-End Context

The end-to-end execution context is defined in `docker-compose.yml`. One might consider it a higher-order context because it is a composition of services that support the execution of the end-to-end tests. The context consists of the following services:

- Selenum Grid [`hub`, `chrome`, `firefox`]
- Angular application [`webapp`]
- Protractor [`protractor`]

The Selenium Grid services are created from official SeleniumHQ Docker images. You can learn more about these images and how to use them [here](https://github.com/SeleniumHQ/docker-selenium).

However, the images used for the Protractor and Angular application services are expressed as environment variables, `TEST_DOCKER_IMAGE` and `DIST_DOCKER_IMAGE` respectively. They are supplied to the call to `docker-compose` in the `Makefile` using an exported environment variable. This prevents the need to update the `docker-compose.yml` file when the project name or version number is changed. Futhermore, the Protractor service uses the test execution context image described above and the Angular application service uses the eventual, final, distributable Docker image.

## Build Steps

Each step in the pipeline, as expressed by the `make` targets, executes a shell script located in the `bin/` folder. The `Makefile` dynamically declares these targets using a convention where any script filename in the `bin/` that begins with `ci-`. The following is a description of each of the build steps.

### `make test`

The `make test` step runs the application unit tests in the test execution context. When executed in the CI/CD context it also publishes code coverage data to Code Climate and publishes reports to S3 at:

    http://angular-pipeline-example.mattupstate.com.s3-website.us-east-2.amazonaws.com/builds/${GIT_COMMIT_SHA}/reports/app/allure/html/
    http://angular-pipeline-example.mattupstate.com.s3-website.us-east-2.amazonaws.com/builds/${GIT_COMMIT_SHA}/reports/app/coverage/

### `make analysis`

The `make analysis` step runs static analysis in the test execution context. When executed in the CI/CD context it publishes the checkstyle output to S3 at:

    http://angular-pipeline-example.mattupstate.com.s3-website.us-east-2.amazonaws.com/builds/${GIT_COMMIT_SHA}/reports/app/lint/checkstyle.xml
    http://angular-pipeline-example.mattupstate.com.s3-website.us-east-2.amazonaws.com/builds/${GIT_COMMIT_SHA}/reports/e2e/lint/checkstyle.xml

### `make audit`

The `make audit` step performs a dependency audit in the test execution context. The script evaluates the combined total of moderate, high, and critical vulnerabilites found in the application dependencies. Should the combined total be higher than the defined threshold the script will print a human readable report and return a non-zero exit code.

### `make e2e`

The `make e2e` step runs the application end-to-end tests in the end-to-end execution context. When executed in the CI/CD context a test report is published to S3 at:

    http://angular-pipeline-example.mattupstate.com.s3-website.us-east-2.amazonaws.com/builds/${GIT_COMMIT_SHA}/reports/e2e/allure/html/

### `make release-candidate`

The `make release-candidate` step copies the build artifacts to S3. Additionally, the artifacts are stored in the bucket using a versioned key prefix such that multiple versions of the application may be accessed using a conventional hostname in the form of:

    http://${GIT_COMMIT_SHA}.angular-pipeline-example.mattupstate.com

The script also publishes release artifacts to [Sentry](https://getsentry.com).

### `make smoke-test`

The `make smoke-tests` step runs a specicialized end-to-end test configuration designed to perform lightweight, non-volatile tests against a release candidate. These tests access the release candidate using the convention hostname described above.

### `make release`

The `make release` step applies changes to the cloud infrastructure that delivers the application on the public internet. More specifically, the Fastly Varnish configuration is updated to point the [default hostname](http://angular-pipeline-example.mattupstate.com) to the release candidate on S3. This procedure is performed using Terraform.

## Public CI Integration

Once I completed the `make` + `docker` based pipeline I integrated the build pipeline with a few public CI services. The following is a brief description of each.

### Semaphore CI

[Semaphore CI](https://semaphoreci.com) is a public CI service. It took only a few tweaks to the pipeline to use the same tooling I use locally. I was a bit surprised, honestly, how easy it was. I didn't have to tell Semaphore to install any of the software I was using. The pipeline exectues exactly how it does on my own machine, which is precisely what I was looking. Couldn't really ask for more! The Semaphore configuration is located in the `.semaphore/` directory.

### Code Climate

[Code Climate](https://codeclimate.com) is a public code quality service. Having learned about it recently (I used to use [coveralls.io](https://coveralls.io)) I figured I'd try it out. It's relatively simple to setup. I've integrated their test reporter tool in the `make test` target. Execution of the test reporter is conditional on being in the CI context. View the project's public Code Climate page [here](https://codeclimate.com/github/mattupstate/angular-pipeline-example).

### Buildkite

While working on this project I discovered [Buildkite](https://buildkite.com). You'll notice a `.buildkite/` folder in this project as well as I wanted to try out their service. Buildkite is different from most public CI services in that you run the build agents. So I've installed the build agent on a commodity Digital Ocean droplet I've had for a while.

## Notes

Finally, here are some notes that describe some of the underlying details.

### Docker Usage

I've purposely not used the `--rm` flag for `docker run` commands. Leaving containers around after executing commands can be helpful when debugging. It also affords me the ability to copy resources out of a stopped container to the host.

### Allure Usage

[Allure](https://docs.qameta.io/allure/) is a test report tool that produces a static web UI and has the option to track testing trends over time. I've configured both the unit and end-to-end tests with an Allure reporter. From the resulting XML the Allure command line tool is then used to generate a report. The reports, along with coverage and checkstyle results, are published to S3.

### DNSimple Usage

DNSimple is my personal DNS management service. In the `./etc/terraform/resources.tf` file you will see two DNS records for this example application:

- angular-pipeline-example.mattupstate.com
- \*.angular-pipeline-example.mattupstate.com

The first is the default, end-user facing record. The second is a wildcard record that, with some unique Varnish configuration for Fastly (described below), affords me the ability to access successful builds of the `master` branch. I thought this might be useful for testing purposes at some point.

Additionally, I've created an API token under my account specific to this project. I've configured Semaphore with this token in order to be able to apply DNS changes during the CI+CD pipeline.

### AWS Usage

AWS S3 is used as a static build artifact repository. I've configured the S3 bucket using the [static hosting feature](https://docs.aws.amazon.com/AmazonS3/latest/dev/WebsiteHosting.html).

Additionally, under my personal AWS account I've created an IAM user to manage API access in the context of Semaphore CI. The access key ID and secret have been provided to Semaphore so that I can automate changes in the CI+CD context.

Finally, for reference, here is the Terraform configuration I've used at the time of this writing to manage the user:

```
provider "aws" {}

terraform {
  backend "s3" {
    region = "us-east-2"
    bucket = "tfstate.mattupstate.com"
    key    = "_global/angular-pipeline-example.mattupstate.com"
  }
}

resource "random_pet" "iam_username" {
  keepers = {
    fqdn = "angular-pipeline-example.mattupstate.com"
  }
}

resource "aws_iam_user" "ci" {
  name = "${random_pet.iam_username.id}"
  path = "/"
  tags = {
      context-description = "Continuous integration services"
      context-url         = "https://mattupstate.semaphoreci.com/projects/angular-pipeline-example"
  }
}

resource "aws_iam_access_key" "ci_user" {
  user    = "${aws_iam_user.ci.name}"
  pgp_key = "keybase:mattupstate"
}

resource "aws_iam_user_policy" "ci" {
  user   = "${aws_iam_user.ci.name}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "s3:ListBucket"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::tfstate.mattupstate.com"
    },
    {
        "Action": [
            "s3:GetObject",
            "s3:PutObject"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::tfstate.mattupstate.com/${random_pet.iam_username.keepers.fqdn}/*"
    },
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
          "arn:aws:s3:::${random_pet.iam_username.keepers.fqdn}",
          "arn:aws:s3:::${random_pet.iam_username.keepers.fqdn}/*"
      ]
    }
  ]
}
EOF
}

output "ci_iam_username" {
    value = "${random_pet.iam_username.id}"
}

output "ci_iam_user_access_key_id" {
    value = "${aws_iam_access_key.ci_user.id}"
}

output "ci_iam_user_access_key_encrypted_secret" {
    value = "${aws_iam_access_key.ci_user.encrypted_secret}"
}
```

### Fastly Usage

Fastly is a CDN, or "edge", service that offers quite a few features. In this example application it is used as a rudimentary reverse proxy. However, it could also be useful for a number of other reasons, such as A/B testing. The following is a description of some of the unique Varnish configuration features that have been provided to the Fastly service.

#### Language Detection

Angular comes out of the box with compile time i18n support. In other words, one must compile a version of the application for each language to be supported. In this example application, each language is deployed in a subfolder using the name of the locale identifier (`${HOSTNAME}/en-US/` or `${HOSTNAME}/es-US/`). The Varnish configuration is then designed to redirect any users that access the site at the root URL to the language for which their browser is primarily configured for using Fastly's [`accept.language_lookup` function](https://docs.fastly.com/guides/vcl-tutorials/accept-language-header-vcl-features). The application then offers a language selection menu should the user want to manually switch to another supported language.

#### AWS S3 Redirects

AWS S3 returns HTTP redirects to force a traling slash on object keys that look like directories in order to load the `index.html` file appropriately. You'll notice some logic in the Varnish configuration that strips the object key prefix so that the redirect bubbles up to the end user's browser appropriately.

#### HTML5 Push State

Angular uses HTML5 push state for routing. Therefore, any time a user accesses the site for the first time using a URL that is not at the root of the application, the HTTP server must load the `index.html` page in order for Angular's router to present the component that maps to the URL. As such, you may also notice that the Varnish configuration will load the `index.html` page for any request that isn't well known file type.

#### Versioned Access

The Varnish configuration is also aware of the wildcard DNS entry (mentioned above) in order to be able to access `master` branch builds. The configuraiton dynamically changes the S3 object key prefix based on the DNS prefix.

### Makefile Extras

#### `make e2e-debug`

There will be times in which it will be unclear as to what is happening within the `chrome` and `firefox` containers when running the end-to-end tests. Thankfully, Selenium offers [debug images that include a VNC server](https://github.com/SeleniumHQ/docker-selenium#debugging) to which you can connect using OS X's built-in VNC client. To afford myself to debug in this manner I've added this `make` target to run the `webapp`, `chrome` and `firefox` services while using the debug Selenium images. First run:

    $ make e2e-debug

And then when all the services running, open another terminal and run:

    $ open vnc://$(docker-compose port chrome 5900)

You will be prompted to enter a password. Enter `secret` and you should then be able to view the desktop GUI. Right-click the desktop and navigate the context menu:

    Applications > Network > Web Browsing > Google Chrome

Once you've reached a browser window, you can then enter `http://webapp` into the address bar to load the application. The Chrome developer tools are also very useful in this context.

### Angular App

#### Segment.com Usage

I've integrated Segment.com into the Angular app as I wanted to do a rudimentary evaluation of how their service works with Google Analytics. Configuration of this service can be seen in `src/app/app.module.providers.ts`.

#### Sentry Usage

I've integrated [Sentry](http://getsentry.com) into the Angular app as I wanted to do a rudimentary evaluation of their hosted service. Initially I tried Rollbar but could not for the life of me figure out how to correlate errors with deploys/versions. At any rate, configuration of the custom error handler can be seen in `src/app/app.module.providers.ts`.

#### Modifications

I initially generated the Angular project using the Angular CLI. However, I added, and made edits to, the following files to suit my needs and preferences.

##### `angular.json`

- Using `@angular-builders/custom-webpack:browser` for the `build` architect target to enhance the webpack configuration.
- Using `@angular-builders/dev-server:generic` for the `serve` architect target to take advantage of the webpack configuration enhancements.
- Using `@angular-builders/custom-webpack:karma` for the `test` architect target to take advantage of the webpack configuration enhancements.
- Changed the `outputPath` value to simply be `dist` instead of `dist/angular-pipeline-example` for the default `build` configuration to avoid having to deal with a named directory in build tooling.
- Added `"codeCoverage": true` to the default `test` options.
- Removed the `production` configurations for all but for `build` as I found them to be unnecessary.
- Added language specific production build configurations.
- Set `"sourceMap": true` in the `build:production-${lang}` configuration because I believe shipping source maps to production is a good thing.

##### `src/karma.conf.js`

- Changed the code coverage report to be saved to `../reports/coverage'

##### `e2e/protractor.*`

I've setup a unique configuration file for each logical `e2e` configuration in `angular.json`. The default configuration, `protractor.conf.js`, is designed to be used locally by developers. Where as `protractor.ci.conf.js` and `protractor.smoke.conf.js` are designed to be used in the CI context.

#### Google Chrome HSTS Snafu

Long story short: the hostname `app` is on Google Chrome's HSTS preload list. This preload list informs Google Chrome to automatically access any content over HTTPS. As such, I had to change the name of the Angular application service in the `docker-compose.yml` file from `app` to `webapp` to prevent Chrome from changing the protocol from HTTP to HTTPS without first contacting the server.

### Local Development Environment

- OS X 10.13.6
- Google Chrome Version 72.0.3626.119
- GNU Make 3.81
- Docker 18.09.2, build 6247962
- docker-compose 1.23.2, build 1110ad01
- node 11.10.0
- npm 6.8.0
- jq 1.5
