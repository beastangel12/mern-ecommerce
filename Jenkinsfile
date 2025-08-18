pipeline {
    agent any

    tools {
        nodejs "NodeJS"   // यो नाम Global Tool Configuration मा define गरेको नाम हो
    }

    stages {
        stage('Install Backend Deps') {
            steps {
                dir('backend') {
                    sh 'npm install'
                }
            }
        }
        stage('Install Frontend Deps & Build') {
            steps {
                dir('frontend') {
                    sh 'npm install'
                    sh 'npm run build'
                }
            }
        }
    }
}
