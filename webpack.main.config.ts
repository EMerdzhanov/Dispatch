import path from 'path';
import type { Configuration } from 'webpack';

const config: Configuration = {
  mode: process.env.NODE_ENV === 'production' ? 'production' : 'development',
  entry: { index: './src/main/index.ts', preload: './src/main/preload.ts' },
  target: 'electron-main',
  module: {
    rules: [{ test: /\.ts$/, use: 'ts-loader', exclude: /node_modules/ }],
  },
  resolve: { extensions: ['.ts', '.js'] },
  output: { path: path.resolve(__dirname, 'dist/main'), filename: '[name].js' },
  externals: { 'node-pty': 'commonjs node-pty' },
};

export default config;
