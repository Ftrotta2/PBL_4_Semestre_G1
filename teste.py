import pandas as pd
from Analise_POO import Grafico

nome = "HOMEFISIO_DADOS_1_SENSOR_20251104_084548.csv"
grafico = Grafico(nome)
grafico.Tempo()
grafico.GerarGrafico()