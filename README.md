# Angular CI Pipeline Example

This repository is the artifact of my experience as I taught myself how to setup an Angular project using the popular CLI tool and provide additional tooling to contributors that runs a build pipeline as it might be run in a Continuous Integration context.

As part of this effort I hope to use a (subjectively) minimal amount of tools that are (subjectively) popular and (subjectively) easy to install such that it can (arguably) be replicated in most modern software development organizations.

## Build Pipeline

The build pipeline can be expressed as a set of ordered steps:

1. Run unit tests
2. Run static analysis
3. Run dependency audit
4. Run end-to-end tests

Implicit in this pipeline are additional steps that build the execution contexts and a distributable application artifact. In this case, the distributable artifact will be a lightweight Docker image based on Nginx that contains the Angular application build artifacts.

I've implemented this pipeline using a `Makefile`. I've chosen `make` as a tool for it's relative ubiquity, stability and simplicity. Each of the following `make` commands map to the logical pipeline steps described above:

1. `make test`
2. `make analysis`
3. `make audit`
4. `make e2e`

A full pipeline, where each step is dependent on a successful completion of the prior step, is executed by running `make build`. Optionally, each step may be executed on its own should one want to shorten the feedback loop.

## Execution Contexts

Docker and Docker Compose are used to manage two primary execution contexts that support the pipeline. I've chosen these tools for their relative ubiquity and popularity. Additionally, these tools affords one to express an execution context in the form of configuration files that are stored in source control and can be (mostly) deterministically built under the assumption that internet infrastructure that delivers dependencies is reliably maintained and secure. The following is a description of each context.

### Test Context

The test execution context is defined in the first stage of the [multi-stage](https://docs.docker.com/develop/develop-images/multistage-build/) `Dockerfile`. It is automatically built prior to executing `make test` `make analysis` or `make audit`. Optionally, `make test-image` is available should one want to build the test context in isolation.

This resulting image, named `angular-pipeline-example:test`, contains all the dependencies required to run unit tests, perform static analysis, audit dependency vulnerabilities, and build the final Angular application artifacts. Pipeline steps that rely on this context will be executed in containers created from this image.

### End-to-End Context

The end-to-end execution context is defined in `docker-compose.yml`. One might consider it a higher-order context because it is a composition of services that support the execution of the end-to-end tests. The context consists of the following services:

- Selenum Grid [`hub`, `chrome`, `firefox`]
- Angular application [`webapp`]
- Protractor [`protractor`]

The Selenium Grid services are created from official SeleniumHQ Docker images. You can learn more about these images and how to use them [here](https://github.com/SeleniumHQ/docker-selenium).

However, the images used for the Protractor and Angular application services are expressed as environment variables, `TEST_DOCKER_IMAGE` and `DIST_DOCKER_IMAGE` respectively. They are supplied to the call to `docker-compose` in the `Makefile` using an exported environment variable. This prevents the need to update the `docker-compose.yml` file when the project name or version number is changed. Futhermore, the Protractor service uses the test execution context image described above and the Angular application service uses the eventual, final, distributable Docker image.

## Build Steps

Each step in the pipeline, as expressed by the `make` targets, executes a `npm run` command in one of the aforementioned execution contexts. Each `npm run` invokes a script that has been designed specifically for a CI environment, whereas the scripts that come out of the box with Angular are generally designed for a local development environment. The following is a description of each of the build steps.

### `make test`

The `make test` step runs the application unit tests in the test execution context. Under the hood it runs the following `docker` command:

    $ docker run --name $(TEST_CONTAINER_NAME) --security-opt seccomp=$(TEST_DOCKER_SECCOMP_FILE) \$(TEST_DOCKER_IMAGE_TAG) npm run test-ci

Notice the `--security-opt` flag. This runs the container in a relatively secure manner and can prevent bad things from happening when executing code in Google Chrome.

The `npm run test-ci` script invokes `ng lint -c ci` which runs the test suite using the `test:ci` configuration expressed in the `angular.json`.

### `make analysis`

The `make analysis` step runs the Angular linting static analysis tool in the test execution context. Under the hood it runs the following `docker` command:

    $ docker run --name $(TEST_CONTAINER_NAME) $(TEST_DOCKER_IMAGE_TAG) npm run lint-ci

The `npm run lint-ci` script invokes `ng lint -c ci > reports/lint/all.txt` which runs the linting tool using the `lint:ci` configuration expressed in the `angular.json`. The configuration instructs the linting tool to produce a machine readable report the output is written to `reports/lint/all.txt`.

### `make audit`

The `make audit` step runs a custom shell script in the test execution context. Under the hood it runs the following `docker` command:

    $ docker run --name $(TEST_CONTAINER_NAME) $(TEST_DOCKER_IMAGE_TAG) npm run audit-ci

The custom shell script behind `npm run audit-ci` evaluates the combined total of moderate, high, and critical vulnerabilites found in the application dependencies. Should the combined total be higher than `0` the script will print a human readable vulnerability report and return a non-zero exit code.

### `make e2e`

The `make e2e` step runs the application end-to-end tests in the end-to-end execution context. This is performed using the following command:

    $ SELENIUM_CHROME_IMAGE=node-chrome SELENIUM_FIREFOX_IMAGE=node-firefox docker-compose up --exit-code-from protractor --force-recreate --remove-orphans --quiet-pull

Docker Compose will run all the specified services and, because the `--exit-code-from protractor` option was used, it will stop all services and return the exit code of the `protractor` service when the `protractor` service container stops.

The command specified to run in the `protractor` services is `wait-for-hub npm run e2e-ci`. This makes use of a custom script (`bin/wait-for-hub`) that waits for the Selenium Hub service to be aware of both Chrome and Firefox. Once ready, the script then calls `ng e2e -c ci` which runs Protractor using the `e2e:ci` configuration expressed in the `angular.json`.

## Putting it All Together

To execute the full pipeline, as it would in a CI context, one would run:

    $ make build

Assuming all steps completed successfully, the name of the Docker image that was built during the pipeline should be visible in the last bit of console output:

```
...
Build completed:
DOCKER_IMAGE=angular-pipline-example:0.1.0
```

Optionally, one can run:

    $ make publish-image

Which will execute the full pipeline and publish the image to the public Docker image registry. The image available as `mattupstate/angular-pipeline-example:0.1.0`

## Semaphore CI Integration

Once I completed the `make` + `docker` based pipeline, I went looking for a hosted CI service that I might be able to run it with. Almost immediately I found [semaphoreci.com](semaphoreci.com). Once I had setup the project with Semaphore, it took only a few tweaks to the pipeline to make it work. I was a bit surprised, honestly, how easy it was. I didn't have to tell Semaphore to install any of the software I was using. The pipeline exectues exactly how it does on my own machine. Couldn't really ask for more!

The Semaphore configuration is located at `.semaphore/semaphore.yml`

## Notes

Finally, here are some notes that describe some of the underlying details.

### Docker Usage

I've purposely not used the `--rm` flag for `docker run` commands. Leaving containers around after executing commands can be helpful when debugging. It also affords me the ability to copy resources out of a stopped container to the host.

### Makefile Extras

#### `make dist-archive`

Sometimes you just want your Angular application packaged up in a plain old archive format. This `make` target products `dist.tar` in the root directory of the project should you want to ship that instead.

#### `make e2e-debug`

There will be times in which it will be unclear as to what is happening within the `chrome` and `firefox` containers when running the end-to-end tests. Thankfully, Selenium offers [debug images that include a VNC server](https://github.com/SeleniumHQ/docker-selenium#debugging) to which you can connect using OS X's built-in VNC client. To afford myself to debug in this manner I've added this `make` target to run the `webapp`, `chrome` and `firefox` services while using the debug Selenium images. First run:

    $ make e2e-debug

And then when all the services running, open another terminal and run:

    $ open vnc://$(docker-compose port chrome 5900)

You will be prompted to enter a password. Enter `secret` and you should then be able to view the desktop GUI. Right-click the desktop and navigate the context menu:

    Applications > Network > Web Browsing > Google Chrome

Once you've reached a browser window, you can then enter `http://webapp` into the address bar to load the application. The Chrome developer tools are also very useful in this context.

### Angular Modificiations

I initially generated the Angular project using the Angular CLI. However, I added, and made edits to, the following files to suit my needs and preferences.

#### `angular.json`

- Changed the `outputPath` value to simply be `dist` instead of `dist/angular-pipline-example` to avoid having to deal with a named directory in build tooling.
- Added `"codeCoverage": true` to the default `test` options.
- Removed the `production` configurations for all but for `build` as I found them to be unnecessary.
- Set `"sourceMap": true` in the `build:production` configuration because I believe shipping source maps to production is a good thing.

#### `src/karma.conf.js`

- Changed the code coverage report to be saved to `../reports/coverage'

#### `e2e/protractor-ci.conf.js`

This is a new file that contains Protractor configuration for the CI context. Reference to this file is made in `angular.json` under the `e2e:ci` configuration. Note the following configuration keys and their values:

- `seleniumAddress`: The URL to reach the Selenium Hub service within the Docker network managed by Docker Compose.
- `multiCapabilities`: Tells Protractor to test against both Chrome and Firefox as afforded through the Selenium Grid.
- `baseUrl`: The URL to reach the Angular application service within the Docker network managed by Docker Compose.

### Google Chrome HSTS Snafu

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
