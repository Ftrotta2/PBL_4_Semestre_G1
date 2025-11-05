import pandas as pd
import threading, queue, time
import matplotlib.pyplot as plt
from Analise_POO import Grafico
from Receptor_POO import Receptor, SalvarArquivo

dados = queue.Queue()

def main():
    print("Testando conexão e Geração de Arquivo!")
    esp32 = Receptor("COM3")
    esp32.ConectarESP32()
    arquivo = SalvarArquivo(qtd_sensores=2)
    arquivo.setHeader()
    input("Pressione enter para iniciar o movimento!")
    arquivo.EscreverArquivo(esp32)
    grafico = Grafico(arquivo.getNomeArquivo())
    grafico.GerarGrafico()

def main_Thread():
    esp32 = Receptor("COM3")
    esp32.ConectarESP32()
    arquivo = SalvarArquivo(qtd_sensores=2)
    arquivo.setHeader()
    arquivo.EscreverArquivo(esp32)

def produtor(arquivo: SalvarArquivo):
    dados.put(arquivo.getDados())
        

def grafico_Thread():
    plt.ion()
    pitch1, roll1, yaw1, tempo = [], [], [], []
    fig, ax = plt.subplots()
    linha1, = ax.plot([],[], label="Pitch")
    linha2, = ax.plot([],[], label="Roll")
    linha3, = ax.plot([],[], label="Yaw")
    ax.legend()
    ax.set_xlabel("Tempo")
    ax.set_ylabel("Ângulo")
    
    while True:
        while not dados.empty():
            p1, r1, y1, t = dados.get()
            tempo.append(t)
            pitch1.append(p1)
            roll1.append(r1)
            yaw1.append(y1)
            
        linha1.set_data(tempo, pitch1)
        linha2.set_data(tempo, roll1)
        linha3.set_data(tempo, yaw1)
        
        ax.relim()
        ax.autoscale_view()
        plt.draw()
        plt.pause(0.01)
    
    
if __name__ == "__main__":
    while True:
        break
        main()
        resposta = input("Deseja realizar outra operação?(s/n)\t")
        if resposta != "s":
            exit()
    main_Thread()
    threading.Thread(target= produtor, daemon=True).start()
    grafico_Thread()