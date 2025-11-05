import pandas as pd
import plotly.express as px
from datetime import datetime

# Aqui temos um objeto que gerará os gráficos a partir do arquivo CSV que é gerado pelo receptor

class Grafico (object):
    def __init__(self, nome_arquivo: str):
        self.membro = ""; # membro inferior da pessoa -> gráfico da coxa / canela / pé
        self.nome_arquivo = nome_arquivo;
        self.df = pd.read_csv(nome_arquivo);
        self.colunas = self.df.columns.tolist();
        match len(self.colunas): # vendo quantas colunas tem, o que indica quantos sensores temos
            case 4: # e consequentemente quantos gráficos serão gerados (o print não é nescessário)
                self.graficos = 1
                self.tamanho = 4
                print("Um gráfico")
            case 7:
                self.graficos = 2
                self.tamanho = 7
                print("Dois gráficos")
            case 10:
                self.graficos = 3
                self.tamanho = 10
                print("Três gráficos")
            case _:
                self.graficos = 0
                self.tamanho = 0
                print("Erro\nGráficos fora do escopo")
    # get e set para o nome do arquivo e membro inferior            
    def getNomeArquivo(self) -> str:
        return self.nome_arquivo;
    def setNomeArquivo(self, nome_arquivo: str):
        self.nome_arquivo = nome_arquivo;
    def getMembro(self) -> str:
        return self.membro
    def setMembro(self, membro: str):
        self.membro = membro
    
    def Tempo(self) -> int: # alterando o tempo de milisegundos para segundos
        ms = self.colunas[self.tamanho -1]
        if ms in self.df.columns and not self.df[ms].isnull().all():
            self.df['tempo_s'] = (self.df[ms] - self.df[ms].iloc[0]) / 1000.0
            return 1
        else:
            print("Erro: Coluna 't_ms' nao encontrada ou esta vazia.")
            return 0
    
    def GerarGrafico(self) -> int: # função que vai gerar os gráficos fazendo um loop de acordo com o número de sensores
        for i in range(self.graficos): # número máx de sensores = 3 (é possivel alterar)
            match i:
                case 0:
                    self.setMembro("Coxa")
                case 1:
                    self.setMembro("Canela")
                case 2:
                    self.setMembro("Pe")
            coluna_inicio = 0 + i*3
            coluna_final = 3 + i*3
            colunas_plot = self.colunas[coluna_inicio:coluna_final]
            nome_imagem = f"./Dados/{self.membro}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            fig = px.line(self.df,
                        x='tempo_s',
                        y = colunas_plot,
                        title=f"Análise do Movimento - {self.membro}",
                        labels={"value": "Angulo (graus)", "tempo_s": "Tempo (segundos)", "variable": "Eixo"})
            fig.update_traces(mode="lines", hovertemplate="<b>%{data.name}</b><br>Tempo: %{x:.2f}s<br>Angulo: %{y:.2f}°")
            fig.update_layout(legend_title_text='Eixo')
            fig.write_image(f"{nome_imagem}.png")