pipeline {
    agent any   
    stages {
        stage('STAGE 1') {
            steps {
                sh 'echo "echoing stage1"'
            }
        }
        stage('STAGE 2') {
            steps {
                sh 'echo "echoing stage2"'
            }
        }
        stage('call ci.sh') {
            steps {
                sh 'sh ci.sh'
                sh 'echo "finisshh"'
            }
        }
    }
    post { 
        always { 
            cleanWs()
        }
    }
}
