#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#Fabio Leandro Lapuinka
import json
import boto3
from datetime import datetime
from dateutil import relativedelta  
from app import SendMessage

sessao = boto3.Session(profile_name='automacao-curso')

cliente_ce = sessao.client('ce')



def get_cost(event, context):

    hoje = datetime.today()
    data_inicial = hoje.strftime('%Y-%m-01')
    mes_seguinte = hoje + relativedelta.relativedelta(months=1)
    data_final =  mes_seguinte.strftime('%Y-%m-01')
    
    resposta = cliente_ce.get_cost_and_usage(
        TimePeriod={
            'Start': data_inicial,
            'End': data_final
        },
        Granularity='DAILY',
        Metrics=[
            'AMORTIZED_COST',
        ]
    )
    valor = resposta['ResultsByTime'][0]['Total']['AmortizedCost']['Amount']
    valor = round(float(valor), 2)
    mensagem = f"O custo da AWS é de {valor} dolares mes"
    SendMessage(mensagem)
    return {"statusCode": 200}

get_cost({},{})



---- Serverless
# "org" ensures this Service is used with the correct Serverless Framework License Key.
org: all4u
# "service" is the name of this project. This will also be added to your AWS resource names.
service: telegramapp

provider:
  name: aws
  runtime: python3.12
  profile: automacao-curso
  stage: prod
  iam:
    role: 
      statements:
        - Effect: Allow
          Action:
            - ce:GetCostAndUsage
          Resource: "*"
  region: us-east-1


functions:
  get_cost:
    handler: handler.get_cost
    events:
      - schedule: 
          rate: cron(0 17 * * ? *)
          enabled: true
          input: {}
      - schedule:
          rate: rate(1 minute)
          enabled: false
          input: {}  

plugins:
  - serverless-python-requirements
package:
  patterns:
    - '!env'
    - '!node_nodules'
    - '!*.json'
