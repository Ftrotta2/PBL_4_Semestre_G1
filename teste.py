import pandas as pd
from Analise_POO import Grafico

nome = "./Dados/HOMEFISIO_DADOS_1_SENSOR_20251104_084548.csv"
grafico = Grafico(nome)
grafico.GerarGrafico()