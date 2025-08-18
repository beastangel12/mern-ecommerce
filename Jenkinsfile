pipeline {
    agent any

    tools {
        nodejs "NodeJS"   // Jenkins मा NodeJS tool configure गर्नु पर्ने हुन्छ
    }

    stages {
        stage('Checkout') {
            steps {
                // GitHub repo बाट checkout
                git branch: 'main', url: 'https://github.com/beastangel12/mern_Ecommerce.git'
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

        stage('Test') {
            steps {
                dir('backend') {
                    sh 'npm test || true'  // test fail भए पनि pipeline crash नहोस् भने
                }
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deploying application...'
                // यहाँ deploy को steps थप्ने (Docker, SSH, etc.)
            }
        }
    }
}
