import pandas as pd
import threading
from Analise_POO import Grafico
from Receptor_POO import Receptor, SalvarArquivo

def main():
    print("Testando conexão e Geração de Arquivo!")
    esp32 = Receptor("COM3")
    esp32 = Receptor("COM3")
    esp32.ConectarESP32()
    arquivo = SalvarArquivo(qtd_sensores=2)
    arquivo.setHeader()
    input("Pressione enter para iniciar o movimento!")
    arquivo.EscreverArquivo(esp32)
    grafico = Grafico(arquivo.getNomeArquivo())
    grafico.GerarGrafico()


def Thread():
    pass
    
if __name__ == "__main__":
    while True:
        main()
        resposta = input("Deseja realizar outra operação?(s/n)\t")
        if resposta != "s":
            exit()