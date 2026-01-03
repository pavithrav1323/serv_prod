import { Request, Response, NextFunction } from 'express';
import multer, { FileFilterCallback, MulterError } from 'multer';

// Extend Express Request type to include file and files
declare module 'express' {
  interface Request {
    file?: Express.Multer.File;
    files?: Express.Multer.File[] | { [fieldname: string]: Express.Multer.File[] };
  }
}

// Configure multer for memory storage (we'll handle the actual upload in the controller)
const storage = multer.memoryStorage();

// File filter to only allow certain file types
const fileFilter = (req: Request, file: Express.Multer.File, cb: FileFilterCallback) => {
  const allowedTypes = ['image/jpeg', 'image/png', 'image/jpg', 'application/pdf'];
  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Invalid file type. Only JPEG, PNG, JPG, and PDF files are allowed.'));
  }
};

// Configure multer with our storage and file filter
const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
});

// Middleware for handling single file uploads
export const uploadSingle = (fieldName: string) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const uploadSingle = upload.single(fieldName);
    
    uploadSingle(req, res, (err: unknown) => {
      if (err) {
        if (err instanceof MulterError) {
          // A Multer error occurred when uploading
          res.status(400).json({ error: err.message });
          return;
        } else if (err instanceof Error) {
          // An unknown error occurred
          res.status(500).json({ error: err.message });
          return;
        }
        res.status(500).json({ error: 'An unknown error occurred during file upload' });
        return;
      }
      next();
    });
    
    return; // Ensure the function always returns
  };
};

// Middleware for handling multiple file uploads
export const uploadMultiple = (fieldName: string, maxCount: number = 5) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const uploadMultiple = upload.array(fieldName, maxCount);
    
    uploadMultiple(req, res, (err: unknown) => {
      if (err) {
        if (err instanceof MulterError) {
          res.status(400).json({ error: err.message });
          return;
        } else if (err instanceof Error) {
          res.status(500).json({ error: err.message });
          return;
        }
        res.status(500).json({ error: 'An unknown error occurred during file upload' });
        return;
      }
      next();
    });
    
    return; // Ensure the function always returns
  };
};

// Middleware for handling multiple fields with files
export const uploadFields = (fields: { name: string; maxCount?: number }[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const uploadFields = upload.fields(fields);
    
    uploadFields(req, res, (err: unknown) => {
      if (err) {
        if (err instanceof MulterError) {
          res.status(400).json({ error: err.message });
          return;
        } else if (err instanceof Error) {
          res.status(500).json({ error: err.message });
          return;
        }
        res.status(500).json({ error: 'An unknown error occurred during file upload' });
        return;
      }
      next();
    });
    
    return; // Ensure the function always returns
  };
};
