pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    choice(name: 'DEPLOY_TARGET', choices: ['staging', 'production'], description: 'Production deployment requires a separate approval and kubeconfig.')
  }

  stages {
    stage('Staging branch only') {
      when { not { branch 'staging' } }
      steps {
        error('This pipeline publishes and deploys only the staging branch.')
      }
    }

    stage('Build and push images') {
      when { branch 'staging' }
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_TOKEN'),
          string(credentialsId: 'stripe-publishable-key', variable: 'VITE_STRIPE_PUBLISHABLE_KEY')
        ]) {
          sh '''
            set -eu
            BACKEND_IMAGE="docker.io/$DOCKERHUB_USER/mern-ecommerce-backend"
            FRONTEND_IMAGE="docker.io/$DOCKERHUB_USER/mern-ecommerce-frontend"
            printf '%s' "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USER" --password-stdin
            docker build --pull -t "$BACKEND_IMAGE:staging" -t "$BACKEND_IMAGE:$BUILD_NUMBER" ./backend
            docker build --pull --build-arg "VITE_STRIPE_PUBLISHABLE_KEY=$VITE_STRIPE_PUBLISHABLE_KEY" -t "$FRONTEND_IMAGE:staging" -t "$FRONTEND_IMAGE:$BUILD_NUMBER" ./frontend
            docker push "$BACKEND_IMAGE:staging"
            docker push "$BACKEND_IMAGE:$BUILD_NUMBER"
            docker push "$FRONTEND_IMAGE:staging"
            docker push "$FRONTEND_IMAGE:$BUILD_NUMBER"
            docker logout
          '''
        }
      }
    }

    stage('Deploy to staging Kubernetes') {
      when {
        allOf {
          branch 'staging'
          expression { params.DEPLOY_TARGET == 'staging' }
        }
      }
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_TOKEN'),
          file(credentialsId: 'staging-kubeconfig', variable: 'KUBECONFIG_FILE')
        ]) {
          sh '''
            set -eu
            export KUBECONFIG="$KUBECONFIG_FILE"
            kubectl apply -f k8s/namespace.yaml
            kubectl apply -f k8s/config.yaml
            for manifest in k8s/mongo.yaml k8s/redis.yaml k8s/backend.yaml k8s/frontend.yaml k8s/backup.yaml; do
              sed "s/dockerhub_user/$DOCKERHUB_USER/g" "$manifest" | kubectl apply -f -
            done
            BACKEND_IMAGE="docker.io/$DOCKERHUB_USER/mern-ecommerce-backend"
            FRONTEND_IMAGE="docker.io/$DOCKERHUB_USER/mern-ecommerce-frontend"
            kubectl -n mern-ecommerce set image deployment/backend backend="$BACKEND_IMAGE:staging"
            kubectl -n mern-ecommerce set image deployment/frontend frontend="$FRONTEND_IMAGE:staging"
            kubectl -n mern-ecommerce rollout status deployment/backend --timeout=180s
            kubectl -n mern-ecommerce rollout status deployment/frontend --timeout=180s
          '''
        }
      }
    }

    stage('Approve production deployment') {
      when {
        allOf {
          branch 'staging'
          expression { params.DEPLOY_TARGET == 'production' }
        }
      }
      steps {
        input message: "Deploy build ${BUILD_NUMBER} from staging to production?", ok: 'Deploy production'
      }
    }

    stage('Deploy to production Kubernetes') {
      when {
        allOf {
          branch 'staging'
          expression { params.DEPLOY_TARGET == 'production' }
        }
      }
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_TOKEN'),
          file(credentialsId: 'production-kubeconfig', variable: 'KUBECONFIG_FILE')
        ]) {
          sh '''
            set -eu
            export KUBECONFIG="$KUBECONFIG_FILE"
            kubectl kustomize k8s/production \
              | sed "s/dockerhub_user/$DOCKERHUB_USER/g;s/IMAGE_TAG/$BUILD_NUMBER/g" \
              | kubectl apply -f -
            kubectl -n production set image deployment/backend "backend=docker.io/$DOCKERHUB_USER/mern-ecommerce-backend:$BUILD_NUMBER"
            kubectl -n production set image deployment/frontend "frontend=docker.io/$DOCKERHUB_USER/mern-ecommerce-frontend:$BUILD_NUMBER"
            kubectl -n production rollout status deployment/backend --timeout=180s
            kubectl -n production rollout status deployment/frontend --timeout=180s
          '''
        }
      }
    }
  }

  post {
    always {
      sh 'docker logout >/dev/null 2>&1 || true'
    }
  }
}
