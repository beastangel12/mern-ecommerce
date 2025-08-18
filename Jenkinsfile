pipeline {
    agent any

    tools {
        nodejs "NodeJS" // must match the name in Global Tool Configuration
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'master', url: 'https://github.com/beastangel12/mern-ecommerce.git'
            }
        }

        stage('Backend deps') {
            steps {
                dir('backend') {
                    sh 'npm install'
                }
            }
        }

        stage('Frontend deps & Build') {
            steps {
                dir('frontend') {
                    sh 'npm install'
                    sh 'npm run build'
                }
            }
        }
    }
}

