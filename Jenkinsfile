node() {
  def checkoutInfo
  def dockerjanusImage
  def dockerTagName

  stage('Checkout') {
    checkoutInfo = checkout scm
    env.GIT_COMMIT = "${checkoutInfo.GIT_COMMIT}"
  }

  if (env.TAG_NAME == null) {
    dockerTagName = env.GIT_COMMIT.take(6)
  } else {
    dockerTagName = env.TAG_NAME
  }

  gitlabBuilds(builds: ["Build", "Tag/Push"]) {
    stage("Build") {
      gitlabCommitStatus("Build") {
        dockerjanusImage = docker.build("endpoint/docker-janus")
      }
    }
    stage("Tag/Push") {
      gitlabCommitStatus("Tag/Push") {
        docker.withRegistry('https://registry.hub.docker.com', 'ep_dockerhub_creds') {
          dockerjanusImage.push("${dockerTagName}")
          if (env.BRANCH_NAME == 'master') {
            dockerjanusImage.push('latest')
          }
        }
      }
    }
  }
}
