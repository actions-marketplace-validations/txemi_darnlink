// CI on the self-hosted forge: a second lap over everything the local hooks and
// the GitHub workflows run. Every stage CALLS the same script they call; nothing
// is reimplemented here.
//
//   gate                 local hook            workflow              stage here
//   tests + self-checks  tools/check.sh        ci.yml / test         local gates pyX.Y
//   dangling links       tools/check.sh        (none)                local gates pyX.Y
//   English: files       tools/check.sh        ci.yml / lang         local gates pyX.Y
//   English: commits     hooks/commit-msg      ci.yml / lang         lang: commit messages
//   English: PR text     (none)                lang-pr.yml           lang: PR title and description
//   packaged build       (none)                ci.yml / smoke        smoke
//   ps1 parses           (none)                ci.yml / ps1-syntax   ps1-syntax
//   private references   (none)                privacy-gate.yml      not here: a private job on the CI server runs tools/privacy_gate.sh
//   secrets in the diff  (private tooling)     (none)                secret-scan
//   repo_policy.yaml     (none)                (none)                repo_policy.yaml
//   English: issues      (none)                lang-issue.yml        not ported: fired by an issue, not a commit
//   release              (none)                publish.yml           not ported: a release job, not a check
//
// No host names, URLs or secrets live in this file: they come from the CI server
// (SECRET_SCAN_URL and the credential 'scm-api-token').

def PYTHONS = ['3.10', '3.11', '3.12', '3.13']

// tools/check.sh is what the local git hooks run. uv honours UV_PYTHON, so the
// same script covers the whole Python matrix.
def localGates(String py, boolean unix) {
  withEnv(["UV_PYTHON=${py}", "UV_PROJECT_ENVIRONMENT=.venv-${py}"]) {
    if (unix) { sh 'bash tools/check.sh' } else { bat 'bash tools/check.sh' }
  }
}

pipeline {
  agent none
  options { timestamps(); disableConcurrentBuilds(); timeout(time: 90, unit: 'MINUTES') }
  stages {
    stage('checks') {
      parallel {

        stage('linux') {
          agent { label 'linux' }
          environment {
            PATH = "${HOME}/.local/bin:${PATH}"
          }
          stages {
            stage('repo_policy.yaml') {
              steps { sh 'python3 tools/repo_policy_check.py' }
            }
            stage('local gates') {
              steps { script { PYTHONS.each { py -> stage("local gates py${py}") { localGates(py, true) } } } }
            }
            stage('pull request context') {
              when { changeRequest() }
              steps {
                withCredentials([
                  usernamePassword(credentialsId: 'scm-api-token', usernameVariable: 'API_USER', passwordVariable: 'API_TOKEN'),
                  gitUsernamePassword(credentialsId: 'scm-api-token')
                ]) {
                  sh '''
                    set -eu
                    # A PR checkout only brings the PR ref: fetch the base explicitly.
                    git fetch --quiet origin "+refs/heads/${CHANGE_TARGET}:refs/remotes/origin/${CHANGE_TARGET}"
                    # The API address is derived from CHANGE_URL; the token stays in the environment.
                    { set +x; } 2>/dev/null
                    PR_TEXT_FILE="${WORKSPACE_TMP}/pr.txt" python3 tools/pr_text.py
                    set -x
                  '''
                }
              }
            }
            stage('lang: commit messages') {
              when { changeRequest() }
              steps { sh 'bash tools/lang_commits.sh "origin/${CHANGE_TARGET}" HEAD' }
            }
            stage('lang: PR title and description') {
              when { changeRequest() }
              steps { sh 'bash tools/lang_gate.sh pr-text "${WORKSPACE_TMP}/pr.txt"' }
            }
            stage('smoke') {
              steps {
                sh '''
                  set -eu
                  uvx --from . darnlink .
                  # The workflow installs from the public URL at this commit. Here the commit
                  # may not be on the public mirror yet, so install over git from the workspace.
                  uvx --from "git+file://${WORKSPACE}@$(git rev-parse HEAD)" darnlink .
                '''
              }
            }
            stage('secret-scan') {
              steps {
                withCredentials([
                  usernamePassword(credentialsId: 'scm-api-token', usernameVariable: 'API_USER', passwordVariable: 'API_TOKEN')
                ]) {
                  sh '''
                    set -eu
                    : "${SECRET_SCAN_URL:?SECRET_SCAN_URL is not set on the CI server. Failing closed.}"
                    { set +x; } 2>/dev/null
                    printf 'header = "Authorization: token %s"\\n' "${API_TOKEN}" | curl -fsSL --config - \
                      "${SECRET_SCAN_URL}" -o "${WORKSPACE_TMP}/secret-scan"
                    set -x
                    # Only what the branch adds is judged; on a branch build, the last commit.
                    if [ -n "${CHANGE_TARGET:-}" ]; then base="origin/${CHANGE_TARGET}"; else base="HEAD~1"; fi
                    python3 "${WORKSPACE_TMP}/secret-scan" --against "$base"
                  '''
                }
              }
            }
          }
        }

        stage('windows') {
          agent { label 'windows' }
          stages {
            stage('local gates') {
              steps { script { PYTHONS.each { py -> stage("local gates py${py} (windows)") { localGates(py, false) } } } }
            }
            stage('smoke') {
              steps { bat 'uvx --from . darnlink .' }
            }
            stage('ps1-syntax') {
              steps { powershell './tools/ps1_syntax.ps1' }
            }
          }
        }

      }
    }
  }
}
