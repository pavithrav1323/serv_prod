import { storage as adminStorage } from '../config/firebase';
import { v4 as uuidv4 } from 'uuid';

export interface UploadedFile {
  fieldname: string;
  originalname: string;
  mimetype: string;
  buffer: Buffer;
  size: number;
}

export interface UploadResult {
  url: string;        // public URL
  name: string;       // object path in bucket
  contentType: string;
  size: number;
}

/**
 * Upload a file to the project's default Firebase Storage bucket,
 * make it PUBLIC, and return its public URL.
 */
export const uploadFile = async (
  file: UploadedFile,
  folder: string = 'uploads'
): Promise<UploadResult> => {
  const bucket = adminStorage.bucket();           // uses the bucket you initialized in config/firebase.ts
  const objectPath = `${folder}/${uuidv4()}-${file.originalname}`;
  const blob = bucket.file(objectPath);

  // Upload the bytes
  await blob.save(file.buffer, {
    resumable: false,
    contentType: file.mimetype,
    metadata: { contentType: file.mimetype },
  });

  // Make the object public (readable by anyone with the URL)
  await blob.makePublic();

  const publicUrl = `https://storage.googleapis.com/${bucket.name}/${objectPath}`;
  return {
    url: publicUrl,
    name: objectPath,
    contentType: file.mimetype,
    size: file.size,
  };
};

export const deleteFile = async (objectPath: string): Promise<void> => {
  const bucket = adminStorage.bucket();
  await bucket.file(objectPath).delete({ ignoreNotFound: true });
};

export const uploadBufferToStorage = async (
  buffer: Buffer,
  originalname: string,
  mimetype: string,
  folder: string = 'tasks'
): Promise<{ url: string; name: string; contentType: string; size: number }> => {
  try {
    const fileName = `${folder}/${uuidv4()}-${originalname}`;
    const bucket = adminStorage.bucket();
    const file = bucket.file(fileName);

    await file.save(buffer, {
      metadata: {
        contentType: mimetype,
      },
    });

    // Make the file publicly accessible
    await file.makePublic();

    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${fileName}`;
    
    return {
      url: publicUrl,
      name: fileName,
      contentType: mimetype,
      size: buffer.length,
    };
  } catch (error) {
    console.error('Error uploading file:', error);
    throw new Error('Failed to upload file to storage');
  }
};

export const buildTaskPath = (taskId: string, fileName: string): string => {
  return `tasks/${taskId}/${fileName}`;
};
