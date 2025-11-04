import pandas as pd
import plotly.express as px

class Grafico (object):
    def __init__(self, nome_arquivo: str):
        self.nome_arquivo = nome_arquivo;
        self.df = pd.read_csv(nome_arquivo);
        self.colunas = self.df.columns.tolist();
        match len(self.colunas):
            case 4:
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
                
    def getNomeArquivo(self) -> str:
        return self.nome_arquivo;
    def setNomeArquivo(self, nome_arquivo: str):
        self.nome_arquivo = nome_arquivo;
    
    def Tempo(self) -> int:
        ms = self.colunas[self.tamanho -1]
        if ms in self.df.columns and not self.df[ms].isnull().all():
            self.df['tempo_s'] = (self.df[ms] - self.df[ms].iloc[0]) / 1000.0
            return 1
        else:
            print("Erro: Coluna 't_ms' nao encontrada ou esta vazia.")
            return 0
    
    def GerarGrafico(self) -> int:
        figura = 1
        colunas_plot = self.colunas[0:3]
        fig = px.line(self.df,
                      x='tempo_s',
                      y = colunas_plot,
                      title=f"Análise do Movimento - {self.graficos}",
                      labels={"value": "Angulo (graus)", "tempo_s": "Tempo (segundos)", "variable": "Eixo"})
        fig.update_traces(mode="lines", hovertemplate="<b>%{data.name}</b><br>Tempo: %{x:.2f}s<br>Angulo: %{y:.2f}°")
        fig.update_layout(legend_title_text='Eixo')
        fig.write_image(f"fig{figura}.png")