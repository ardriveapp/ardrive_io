self.onmessage = function(event) {
  console.log('worker.js: onmessage');
  const { file, start, end, chunkSize } = event.data;
  let globalOffset = start;

  console.log('worker.js: file', file);
  console.log('worker.js: start', start);
  console.log('worker.js: end', end);
  while (globalOffset < end) {
    console.log('worker.js: globalOffset', globalOffset);
    const chunkEnd = Math.min(globalOffset + chunkSize, end);
    const blob = file.slice(globalOffset, chunkEnd);
    const reader = new FileReader();
    
    reader.onload = function() {
      self.postMessage({ chunk: reader.result, chunkSize: chunkSize });
      globalOffset += chunkSize;
      logger.log('worker.js: globalOffset', globalOffset);
    };

    reader.readAsArrayBuffer(blob);
  }
};