import path from 'path';
import HtmlWebpackPlugin from 'html-webpack-plugin';
import type { Configuration } from 'webpack';
import type { Configuration as DevServerConfiguration } from 'webpack-dev-server';

type WebpackConfig = Configuration & { devServer?: DevServerConfiguration };

const config: WebpackConfig = {
  mode: process.env.NODE_ENV === 'production' ? 'production' : 'development',
  entry: './src/renderer/index.tsx',
  target: 'web',
  module: {
    rules: [
      { test: /\.tsx?$/, use: 'ts-loader', exclude: /node_modules/ },
      { test: /\.css$/, use: ['style-loader', 'css-loader', 'postcss-loader'] },
    ],
  },
  resolve: { extensions: ['.tsx', '.ts', '.js'] },
  output: { path: path.resolve(__dirname, 'dist/renderer'), filename: 'bundle.js' },
  plugins: [
    new HtmlWebpackPlugin({ template: './src/renderer/index.html' }),
  ],
  devServer: { port: 8080, hot: true },
};

export default config;
