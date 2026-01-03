import { Router } from 'express';
import * as employeeController from '../controllers/employeeController';
import { authMiddleware, roleMiddleware } from '../middlewares/authMiddleware';

const router = Router();

// All /employees routes require auth
router.use(authMiddleware);

/**
 * @swagger
 * components:
 *   schemas:
 *     Employee:
 *       type: object
 *       properties:
 *         id: { type: string }
 *         empid: { type: string }
 *         name: { type: string }
 *         email: { type: string }
 *         phone: { type: string }
 *         location: { type: string }
 *         dept: { type: string }
 *         designation: { type: string }
 *         shiftGroup: { type: string }
 *         role: { type: string }
 *         status:
 *           type: string
 *           enum: [active, inactive]
 *         createdAt: { type: string, format: date-time }
 *         updatedAt: { type: string, format: date-time }
 *         createdBy: { type: string }
 *         updatedBy: { type: string }
 *       required: [empid, name, email, status]
 */

/**
 * @swagger
 * /api/employees:
 *   post:
 *     summary: Create a new employee (Admin only)
 *     tags: [Employees]
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Employee'
 *     responses:
 *       201: { description: Employee created successfully }
 *       400: { description: Missing required fields }
 *       409: { description: Employee with this ID or email already exists }
 *       500: { description: Internal server error }
 */
router.post('/', roleMiddleware(['admin']), employeeController.createEmployee);

/**
 * @swagger
 * /api/employees:
 *   get:
 *     summary: Get all employees with pagination and filtering (Admin only)
 *     tags: [Employees]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [active, inactive] }
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *         description: Search tokens for name/email/empid/phone/department/designation
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 10 }
 *     responses:
 *       200:
 *         description: List of employees
 */
router.get('/', roleMiddleware(['admin']), employeeController.getEmployees);

/**
 * @swagger
 * /api/employees/{id}:
 *   get:
 *     summary: Get employee by ID (Admin or self via other guards)
 *     tags: [Employees]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200: { description: Employee details }
 *       404: { description: Employee not found }
 */
router.get('/:id', roleMiddleware(['admin']), employeeController.getEmployeeById);

/**
 * @swagger
 * /api/employees/{id}:
 *   put:
 *     summary: Update employee (Admin only)
 *     tags: [Employees]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Employee'
 *     responses:
 *       200: { description: Employee updated successfully }
 *       404: { description: Employee not found }
 */
router.put('/:id', roleMiddleware(['admin']), employeeController.updateEmployee);

/**
 * @swagger
 * /api/employees/{id}:
 *   delete:
 *     summary: Delete an employee (Admin only)
 *     tags: [Employees]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200: { description: Employee deleted successfully }
 */
router.delete('/:id', roleMiddleware(['admin']), employeeController.deleteEmployee);

export default router;
