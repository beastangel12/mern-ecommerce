pipeline {
    agent any
    environment {
        INVENTORY = 'ansible/inventory.ini'
        PLAYBOOK  = 'ansible/deploy.yml'
        SSH_CREDS = 'app-server-ssh'
        REPO      = 'https://github.com/beastangel12/mern-ecommerce.git'
        BRANCH    = 'master'
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: "${BRANCH}", url: "${REPO}"
            }
        }
        stage('Backend deps') {
            steps {
                sh 'npm ci --prefix backend'
            }
        }
        stage('Frontend deps & Build') {
            steps {
                sh 'npm ci --prefix frontend'
                sh 'npm run build --prefix frontend'
            }
        }
        stage('Deploy via Ansible') {
            steps {
                sshagent([env.SSH_CREDS]) {
                    sh "ansible-playbook -i ${INVENTORY} ${PLAYBOOK}"
                }
            }
        }
    }
    post {
        success {
            echo '✅ Deployment completed.'
        }
        failure {
            echo '❌ Pipeline failed.'
        }
    }
}
