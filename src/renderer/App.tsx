import React from 'react';

export function App() {
  return (
    <div className="flex flex-col h-screen bg-[#0a0a1a] text-white">
      <div className="h-10 bg-[#1a1a2e] border-b border-[#333] flex items-center px-4 text-sm text-gray-400">
        Dispatch
      </div>
      <div className="flex flex-1 overflow-hidden">
        <div className="w-56 bg-[#0f0f23] border-r border-[#333]">
          Sidebar
        </div>
        <div className="flex-1 bg-[#0a0a1a] flex items-center justify-center text-gray-600">
          No terminal open
        </div>
      </div>
    </div>
  );
}
