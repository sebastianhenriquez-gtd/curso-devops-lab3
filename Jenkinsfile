pipeline {
    agent any

    environment {
        DOCKERHUB_CREDS   = 'dockerhub-creds'
        GITHUB_CREDS      = 'github-creds'
        DOCKERHUB_IMAGE   = 'sebahenriquez/curso-devops-lab3'
        GHCR_IMAGE        = 'ghcr.io/sebastianhenriquez-gtd/curso-devops-lab3'
        K8S_NAMESPACE     = 'shenriquez'
        K8S_DEPLOYMENT    = 'curso-devops-lab3'
        K8S_CONTAINER     = 'curso-devops-lab3'
    }

    stages {

        // a. Instalación de dependencias
        stage('Install dependencies') {
            steps {
                sh 'npm ci'
            }
        }

        // b. Ejecución de pruebas
        stage('Run tests') {
            steps {
                sh 'npm run test:cov'
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/junit.xml'
                }
            }
        }

        // c. Envío de cobertura a SonarQube y validación de puerta de calidad
        stage('SonarQube analysis') {
            when { expression { return false } }
            steps {
                script {
                    def scannerHome = tool 'SonarScanner'
                    withSonarQubeEnv('sonarqube-local') {
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                              -Dsonar.projectKey=curso-devops-lab3 \
                              -Dsonar.projectName=curso-devops-lab3 \
                              -Dsonar.sources=src \
                              -Dsonar.exclusions=**/*.spec.ts \
                              -Dsonar.tests=src \
                              -Dsonar.test.inclusions=**/*.spec.ts \
                              -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \
                              -Dsonar.nodejs.executable=\$(which node)
                        """
                    }
                }
            }
        }

        stage('Quality Gate') {
            when { expression { return false } }
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // d. Build de la aplicación
        stage('Build application') {
            steps {
                sh 'npm run build'
            }
        }

        // Determina la versión semántica desde package.json
        stage('Resolve version') {
            steps {
                script {
                    env.SEMVER = sh(
                        script: "node -e \"console.log(require('./package.json').version)\"",
                        returnStdout: true
                    ).trim()
                    echo "Versión semántica detectada: ${env.SEMVER}"
                    echo "Build number: ${env.BUILD_NUMBER}"
                }
            }
        }

        // e. Construcción de imagen docker multistage (liviana)
        stage('Build docker image') {
            steps {
                script {
                    dockerImage = docker.build("${DOCKERHUB_IMAGE}:${env.BUILD_NUMBER}")
                }
            }
        }

        // f. Upload de imagen a Docker Hub (latest, semver, build number)
        stage('Push to Docker Hub') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', DOCKERHUB_CREDS) {
                        dockerImage.push("${env.BUILD_NUMBER}")
                        dockerImage.push("${env.SEMVER}")
                        dockerImage.push('latest')
                    }
                }
            }
        }

        // g. Upload de imagen a GitHub Packages / GHCR (latest, semver, build number)
        stage('Push to GHCR') {
            steps {
                script {
                    sh "docker tag ${DOCKERHUB_IMAGE}:${env.BUILD_NUMBER} ${GHCR_IMAGE}:${env.BUILD_NUMBER}"
                    sh "docker tag ${DOCKERHUB_IMAGE}:${env.BUILD_NUMBER} ${GHCR_IMAGE}:${env.SEMVER}"
                    sh "docker tag ${DOCKERHUB_IMAGE}:${env.BUILD_NUMBER} ${GHCR_IMAGE}:latest"

                    docker.withRegistry('https://ghcr.io', GITHUB_CREDS) {
                        sh "docker push ${GHCR_IMAGE}:${env.BUILD_NUMBER}"
                        sh "docker push ${GHCR_IMAGE}:${env.SEMVER}"
                        sh "docker push ${GHCR_IMAGE}:latest"
                    }
                }
            }
        }

        // h. Actualización de imagen de kubernetes local usando build number
        stage('Deploy to local Kubernetes') {
            steps {
                sh """
                    kubectl set image deployment/${K8S_DEPLOYMENT} \
                      ${K8S_CONTAINER}=${GHCR_IMAGE}:${env.BUILD_NUMBER} \
                      -n ${K8S_NAMESPACE}
                    kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=120s
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline completado correctamente. Imagen: ${GHCR_IMAGE}:${env.BUILD_NUMBER}"
        }
        failure {
            echo 'El pipeline falló. Revisa los logs de la etapa correspondiente.'
        }
    }
}
